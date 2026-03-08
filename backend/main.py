import os
import shutil
import json
import uuid
from datetime import datetime
from typing import List, Optional
from fastapi import FastAPI, UploadFile, File, Form, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from pymongo import MongoClient
from bson import ObjectId

app = FastAPI()

# --- CONFIG ---
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
UPLOADS_DIR = os.path.join(BASE_DIR, "uploads")
if not os.path.exists(UPLOADS_DIR): os.makedirs(UPLOADS_DIR)
app.mount("/uploads", StaticFiles(directory=UPLOADS_DIR), name="uploads")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- DATABASE ---
client = MongoClient("mongodb://localhost:27017/")
db = client.proxi_social_db

# --- WEBSOCKET MANAGER ---
class ConnectionManager:
    def __init__(self):
        self.active_connections: dict[str, WebSocket] = {}

    async def connect(self, websocket: WebSocket, username: str):
        await websocket.accept()
        self.active_connections[username] = websocket

    def disconnect(self, username: str):
        if username in self.active_connections:
            del self.active_connections[username]

    async def send_msg(self, message: dict, receiver: str):
        if receiver in self.active_connections:
            await self.active_connections[receiver].send_json(message)

manager = ConnectionManager()

def fix_id(doc):
    if doc: doc['_id'] = str(doc['_id'])
    return doc

# --- AUTH ROUTES ---

@app.post("/auth/login")
def login(username: str = Form(...), password: str = Form(...)):
    user = db.users.find_one({"username": username})
    if not user:
        user = {
            "username": username,
            "password": password,
            "avatar_formal": f"https://ui-avatars.com/api/?name={username}&background=0D8ABC&color=fff&size=128", 
            "avatar_casual": f"https://api.dicebear.com/7.x/pixel-art/png?seed={username}", 
            "bio": "New to Proxi",
            "ble_uuid": str(uuid.uuid4()),
            "followers": [],
            "following": []
        }
        db.users.insert_one(user)
    return {"status": "success", "user": fix_id(user)}

@app.get("/users/nearby")
def get_nearby():
    return [fix_id(u) for u in db.users.find({}, {"password": 0})]

# --- CONTENT ROUTES ---

@app.post("/content/create")
async def create_content(
    username: str = Form(...),
    text: str = Form(...),
    mode: str = Form(...),
    type: str = Form(...),
    file: UploadFile = File(None)
):
    media_url = None
    if file:
        fname = f"{int(datetime.now().timestamp())}_{file.filename}"
        with open(os.path.join(UPLOADS_DIR, fname), "wb+") as f:
            shutil.copyfileobj(file.file, f)
        media_url = f"/uploads/{fname}"

    item = {
        "username": username,
        "text": text,
        "mode": mode,
        "type": type,
        "media_url": media_url,
        "timestamp": datetime.now().isoformat(),
        "likes": [],
        "comments": [],
        # This ensures we know which avatar to show even if we don't join tables
        "author_avatar": "" 
    }
    
    # Store immediate avatar for consistency
    u = db.users.find_one({"username": username})
    if u:
        item["author_avatar"] = u.get(f'avatar_{mode.lower()}', "")

    if type == 'story':
        db.stories.insert_one(item)
    else:
        db.posts.insert_one(item)
        
    return {"status": "success"}

@app.get("/feed")
def get_feed(mode: str):
    # This fetches ALL posts for the mode, including your own.
    posts = list(db.posts.find({"mode": mode}).sort("timestamp", -1))
    stories = list(db.stories.find({"mode": mode}).sort("timestamp", -1))
    
    # Refresh avatars in case user updated them
    for p in posts:
        u = db.users.find_one({"username": p['username']})
        if u: p['author_avatar'] = u.get(f'avatar_{mode.lower()}', "")
    
    for s in stories:
        u = db.users.find_one({"username": s['username']})
        if u: s['author_avatar'] = u.get(f'avatar_{mode.lower()}', "")

    return {"posts": [fix_id(p) for p in posts], "stories": [fix_id(s) for s in stories]}

@app.get("/user/posts/{username}")
def get_user_posts(username: str):
    # Fetch ALL posts by user regardless of mode for their profile
    posts = list(db.posts.find({"username": username}).sort("timestamp", -1))
    return [fix_id(p) for p in posts]

@app.post("/post/interact")
def interact(
    id: str = Form(...), 
    username: str = Form(...), 
    action: str = Form(...), 
    comment: str = Form(None)
):
    post = db.posts.find_one({"_id": ObjectId(id)})
    if not post: return {"status": "error"}

    if action == 'like':
        if username in post.get('likes', []):
            db.posts.update_one({"_id": ObjectId(id)}, {"$pull": {"likes": username}})
        else:
            db.posts.update_one({"_id": ObjectId(id)}, {"$addToSet": {"likes": username}})
            if post['username'] != username:
                db.notifications.insert_one({
                    "to": post['username'], "from": username, "type": "like", "post_id": id, "text": "liked your post.", "timestamp": datetime.now().isoformat()
                })

    elif action == 'comment':
        db.posts.update_one({"_id": ObjectId(id)}, {"$push": {"comments": {"user": username, "text": comment, "timestamp": datetime.now().isoformat()}}})
        if post['username'] != username:
            db.notifications.insert_one({
                "to": post['username'], "from": username, "type": "comment", "post_id": id, "text": f"commented: {comment}", "timestamp": datetime.now().isoformat()
            })

    return {"status": "success"}

@app.get("/notifications/{username}")
def get_notifications(username: str):
    notifs = list(db.notifications.find({"to": username}).sort("timestamp", -1))
    return [fix_id(n) for n in notifs]

# --- CHAT & STORY REPLIES ---

@app.post("/chat/send_http")
async def send_http_message(
    sender: str = Form(...), 
    receiver: str = Form(...), 
    text: str = Form(...)
):
    # Allows sending a message (Story Reply) without a WebSocket connection
    msg_doc = {
        "sender": sender,
        "receiver": receiver,
        "text": text,
        "file_url": None,
        "file_type": "text",
        "timestamp": datetime.now().isoformat()
    }
    db.messages.insert_one(msg_doc)
    # Try to push to websocket if user is online
    await manager.send_msg(fix_id(msg_doc), receiver)
    return {"status": "success"}

@app.post("/chat/upload")
async def upload_chat_file(file: UploadFile = File(...)):
    fname = f"chat_{int(datetime.now().timestamp())}_{file.filename}"
    with open(os.path.join(UPLOADS_DIR, fname), "wb+") as f:
        shutil.copyfileobj(file.file, f)
    return {"url": f"/uploads/{fname}", "type": file.content_type}

@app.websocket("/ws/{username}")
async def ws_endpoint(websocket: WebSocket, username: str):
    await manager.connect(websocket, username)
    try:
        while True:
            data = await websocket.receive_json()
            msg_doc = {
                "sender": username,
                "receiver": data['to'],
                "text": data.get('text', ''),
                "file_url": data.get('file_url'),
                "file_type": data.get('file_type'),
                "timestamp": datetime.now().isoformat()
            }
            db.messages.insert_one(msg_doc)
            await manager.send_msg(fix_id(msg_doc), data['to'])
    except WebSocketDisconnect:
        manager.disconnect(username)

@app.get("/chat/history/{user1}/{user2}")
def get_history(user1: str, user2: str):
    msgs = list(db.messages.find({
        "$or": [
            {"sender": user1, "receiver": user2},
            {"sender": user2, "receiver": user1}
        ]
    }).sort("timestamp", 1))
    return [fix_id(m) for m in msgs]
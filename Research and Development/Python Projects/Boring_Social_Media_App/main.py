from fastapi import FastAPI, Depends, HTTPException
from fastapi.responses import HTMLResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import inspect
import models, database

app = FastAPI(title="Boring App - Payroll Aggregator API-based Social Media App")

app.mount("/static", StaticFiles(directory="static"), name="static")

def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.on_event("startup")
def startup_event():
    models.Base.metadata.create_all(bind=database.engine)
    
    # Non-destructive schema check: add any missing columns via ALTER TABLE instead of dropping tables
    inspector = inspect(database.engine)
    if "users" in inspector.get_table_names():
        columns = [c["name"] for c in inspector.get_columns("users")]
        expected_columns = {
            "show_boring_posts": "BOOLEAN DEFAULT 1",
            "show_timecards": "BOOLEAN DEFAULT 1",
            "show_total_payout": "BOOLEAN DEFAULT 1",
            "hide_hris_connections": "BOOLEAN DEFAULT 0",
            "asm_gm_alert": "BOOLEAN DEFAULT 1",
            "import_history": "BOOLEAN DEFAULT 0",
            "payroll_connected": "BOOLEAN DEFAULT 0",
            "payroll_provider": "VARCHAR",
            "company_role": "VARCHAR"
        }
        with database.engine.connect() as conn:
            for col, col_type in expected_columns.items():
                if col not in columns:
                    try:
                        conn.execute(database.text(f"ALTER TABLE users ADD COLUMN {col} {col_type}"))
                        conn.commit()
                    except Exception as e:
                        print(f"Migration note for {col}: {e}")

    db = database.SessionLocal()
    try:
        existing_user = db.query(models.User).first()
        if not existing_user:
            user = models.User(
                first_name="Custom",
                last_name="User",
                birthday="01/01/1995",
                email="custom@user.com",
                hashed_password="secretpassword",
                username="originalusername",
                display_name="CustomUserName",
                company_role="Associate Chair Lifter at Waffle House",
                payroll_connected=True,
                payroll_provider="Workday",
                import_history=True
            )
            db.add(user)
            db.commit()
            db.refresh(user)
    finally:
        db.close()

class SignUpRequest(BaseModel):
    first_name: str
    last_name: str
    birthday: str
    email: str
    password: str
    payroll_provider: str | None = None

class LoginRequest(BaseModel):
    email: str
    password: str

class OnboardingRequest(BaseModel):
    user_id: int
    import_history: bool
    username: str
    display_name: str

class PostCreate(BaseModel):
    post_type: str
    title: str
    content: str
    time_category: str = "Today"
    user_id: int = 1

class CommentCreate(BaseModel):
    content: str
    user_id: int = 1

class SettingsUpdate(BaseModel):
    show_boring_posts: bool
    show_timecards: bool
    show_total_payout: bool
    hide_hris_connections: bool
    asm_gm_alert: bool

@app.post("/api/signup")
def signup(data: SignUpRequest, db: Session = Depends(get_db)):
    existing = db.query(models.User).filter_by(email=data.email).first()
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    new_user = models.User(
        first_name=data.first_name,
        last_name=data.last_name,
        birthday=data.birthday,
        email=data.email,
        hashed_password=data.password,
        username=data.email.split("@")[0],
        display_name=f"{data.first_name} {data.last_name}",
        company_role="Associate Chair Lifter at Waffle House",
        payroll_connected=bool(data.payroll_provider),
        payroll_provider=data.payroll_provider
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return {"message": "Signup successful", "user_id": new_user.id, "display_name": new_user.display_name, "role": new_user.company_role}

@app.post("/api/login")
def login(data: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(models.User).filter_by(email=data.email).first()
    if not user or user.hashed_password != data.password:
        raise HTTPException(status_code=400, detail="Invalid email or password")
    return {
        "message": "Login successful",
        "user_id": user.id,
        "username": user.username,
        "display_name": user.display_name,
        "role": user.company_role
    }

@app.post("/api/onboarding")
def onboarding(data: OnboardingRequest, db: Session = Depends(get_db)):
    user = db.query(models.User).filter_by(id=data.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.import_history = data.import_history
    user.username = data.username
    user.display_name = data.display_name
    db.commit()

    if data.import_history and user.payroll_provider:
        provider = user.payroll_provider
        history_posts = [
            {
                "post_type": "boring",
                "title": f"Imported Payout from {provider}",
                "content": f"Successfully synced historical direct deposit of $1,250.00 via {provider} API stub.",
                "time_category": "Last Week",
                "user_id": user.id
            },
            {
                "post_type": "timecard",
                "title": f"Synced Timecard from {provider}",
                "content": f"Clocked in 40 hours for last week via {provider}.",
                "time_category": "Last Week",
                "user_id": user.id
            }
        ]
        for hp in history_posts:
            db.add(models.Post(**hp))
        db.commit()

    return {"message": "Onboarding complete", "username": user.username, "display_name": user.display_name}

@app.get("/api/stats")
def get_stats(db: Session = Depends(get_db)):
    user_count = db.query(models.User).count()
    post_count = db.query(models.Post).count()
    return {"total_users": user_count, "total_posts": post_count}

@app.get("/api/posts")
def get_posts(db: Session = Depends(get_db)):
    posts = db.query(models.Post).order_by(models.Post.id.desc()).all()
    result = []
    for p in posts:
        result.append({
            "id": p.id,
            "post_type": p.post_type,
            "title": p.title,
            "content": p.content,
            "time_category": p.time_category,
            "username": p.owner.username if p.owner else "originalusername",
            "display_name": p.owner.display_name if p.owner else "CustomUserName",
            "likes_count": len(p.likes),
            "comments": [{"id": c.id, "content": c.content, "username": c.user.username if c.user else "originalusername"} for c in p.comments]
        })
    return result

@app.post("/api/posts")
def create_post(post: PostCreate, db: Session = Depends(get_db)):
    db_post = models.Post(
        post_type=post.post_type,
        title=post.title,
        content=post.content,
        time_category=post.time_category,
        user_id=post.user_id
    )
    db.add(db_post)
    db.commit()
    db.refresh(db_post)
    return {"message": "Boring Post published", "id": db_post.id}

@app.post("/api/posts/{post_id}/like")
def toggle_like(post_id: int, user_id: int = 1, db: Session = Depends(get_db)):
    existing = db.query(models.Like).filter_by(post_id=post_id, user_id=user_id).first()
    if existing:
        db.delete(existing)
        liked = False
    else:
        db.add(models.Like(post_id=post_id, user_id=user_id))
        liked = True
    db.commit()
    likes_count = db.query(models.Like).filter_by(post_id=post_id).count()
    return {"liked": liked, "likes_count": likes_count}

@app.post("/api/posts/{post_id}/comments")
def add_comment(post_id: int, comment: CommentCreate, db: Session = Depends(get_db)):
    db_comment = models.Comment(content=comment.content, post_id=post_id, user_id=comment.user_id)
    db.add(db_comment)
    db.commit()
    db.refresh(db_comment)
    return {"message": "Comment added", "id": db_comment.id}

@app.get("/api/user/{user_id}/settings")
def get_settings(user_id: int, db: Session = Depends(get_db)):
    user = db.query(models.User).filter_by(id=user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return {
        "username": user.username,
        "show_boring_posts": user.show_boring_posts,
        "show_timecards": user.show_timecards,
        "show_total_payout": user.show_total_payout,
        "hide_hris_connections": user.hide_hris_connections,
        "asm_gm_alert": user.asm_gm_alert,
        "payroll_provider": user.payroll_provider or "None (Coming Soon)"
    }

@app.put("/api/user/{user_id}/settings")
def update_settings(user_id: int, settings: SettingsUpdate, db: Session = Depends(get_db)):
    user = db.query(models.User).filter_by(id=user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.show_boring_posts = settings.show_boring_posts
    user.show_timecards = settings.show_timecards
    user.show_total_payout = settings.show_total_payout
    user.hide_hris_connections = settings.hide_hris_connections
    user.asm_gm_alert = settings.asm_gm_alert
    db.commit()
    return {"message": "Settings updated successfully"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)


@app.get("/", response_class=HTMLResponse)
def read_index():
    with open("static/index.html", "r", encoding="utf-8") as f:
        return f.read()

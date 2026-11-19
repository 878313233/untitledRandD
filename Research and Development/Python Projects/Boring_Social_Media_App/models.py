from sqlalchemy import Column, Integer, String, Text, ForeignKey, DateTime, Boolean
from sqlalchemy.orm import relationship
from datetime import datetime
from database import Base

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    first_name = Column(String, nullable=False)
    last_name = Column(String, nullable=False)
    birthday = Column(String, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    username = Column(String, unique=True, index=True, nullable=False)
    display_name = Column(String, nullable=False)
    company_role = Column(String, nullable=True) # e.g. "Associate Chair Lifter at Waffle House"
    payroll_connected = Column(Boolean, default=False)
    payroll_provider = Column(String, nullable=True) # e.g. "Workday", "Rippling"
    import_history = Column(Boolean, default=False)

    # Privacy Settings
    show_boring_posts = Column(Boolean, default=True)
    show_timecards = Column(Boolean, default=True)
    show_total_payout = Column(Boolean, default=True)
    hide_hris_connections = Column(Boolean, default=False)
    asm_gm_alert = Column(Boolean, default=True)

    posts = relationship("Post", back_populates="owner", cascade="all, delete-orphan")
    comments = relationship("Comment", back_populates="user", cascade="all, delete-orphan")
    likes = relationship("Like", back_populates="user", cascade="all, delete-orphan")

class Post(Base):
    __tablename__ = "posts"
    id = Column(Integer, primary_key=True, index=True)
    post_type = Column(String, nullable=False) # "boring", "timecard", "purchase", "promotion", "fired"
    title = Column(String, nullable=False) # e.g. "Boring from Walmart", "Purchase from Costco"
    content = Column(Text, nullable=False)
    time_category = Column(String, nullable=False, default="Today") # "Today", "Yesterday", "Last Week"
    user_id = Column(Integer, ForeignKey("users.id"))
    created_at = Column(DateTime, default=datetime.utcnow)

    owner = relationship("User", back_populates="posts")
    comments = relationship("Comment", back_populates="post", cascade="all, delete-orphan")
    likes = relationship("Like", back_populates="post", cascade="all, delete-orphan")

class Comment(Base):
    __tablename__ = "comments"
    id = Column(Integer, primary_key=True, index=True)
    content = Column(Text, nullable=False)
    post_id = Column(Integer, ForeignKey("posts.id"))
    user_id = Column(Integer, ForeignKey("users.id"))

    post = relationship("Post", back_populates="comments")
    user = relationship("User", back_populates="comments")

class Like(Base):
    __tablename__ = "likes"
    id = Column(Integer, primary_key=True, index=True)
    post_id = Column(Integer, ForeignKey("posts.id"))
    user_id = Column(Integer, ForeignKey("users.id"))

    post = relationship("Post", back_populates="likes")
    user = relationship("User", back_populates="likes")

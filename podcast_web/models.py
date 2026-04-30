from sqlalchemy import Column, Integer, String, Text

from podcast_web.db import Base


class Job(Base):
    __tablename__ = "jobs"

    id = Column(Integer, primary_key=True)
    filename = Column(String(255), nullable=False)
    source_path = Column(Text, nullable=False)
    status = Column(String(32), nullable=False, default="queued")
    output_path = Column(Text, nullable=True)
    error_message = Column(Text, nullable=True)

from __future__ import annotations

from contextlib import contextmanager

from podcast_web.models import Job


class JobRepository:
    def __init__(self, session_factory):
        self.session_factory = session_factory

    @contextmanager
    def session(self):
        session = self.session_factory()
        try:
            yield session
            session.commit()
        except Exception:
            session.rollback()
            raise
        finally:
            session.close()

    def create_job(self, filename: str, source_path: str, status: str = "queued") -> Job:
        with self.session() as session:
            job = Job(filename=filename, source_path=source_path, status=status)
            session.add(job)
            session.flush()
            session.refresh(job)
            session.expunge(job)
            return job

    def update_job(self, job_id: int, **fields) -> Job:
        with self.session() as session:
            job = session.get(Job, job_id)
            for key, value in fields.items():
                setattr(job, key, value)
            session.add(job)
            session.flush()
            session.refresh(job)
            session.expunge(job)
            return job

    def get_job(self, job_id: int) -> Job:
        with self.session() as session:
            job = session.get(Job, job_id)
            session.expunge(job)
            return job

    def list_jobs(self):
        with self.session() as session:
            jobs = session.query(Job).order_by(Job.id.desc()).all()
            for job in jobs:
                session.expunge(job)
            return jobs

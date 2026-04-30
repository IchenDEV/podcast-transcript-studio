from fastapi.testclient import TestClient


def test_smoke_seeded_completed_job_renders_result(tmp_path):
    from podcast_web.app import create_app

    app = create_app(testing=True)
    client = TestClient(app)

    response = client.post('/demo/seed')
    assert response.status_code == 200
    payload = response.json()
    job_id = payload['job_id']

    detail = client.get(f'/jobs/{job_id}')
    assert detail.status_code == 200
    assert 'Demo transcript line' in detail.text

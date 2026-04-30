from fastapi import FastAPI


def test_app_boots_with_expected_routes():
    from podcast_web.app import create_app

    app = create_app(testing=True)

    assert isinstance(app, FastAPI)
    assert app.title == "Podcast Transcript Studio"

    route_paths = {route.path for route in app.routes}
    assert "/" in route_paths
    assert "/jobs" in route_paths

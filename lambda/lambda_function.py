import base64
import json
import os
import time

import boto3

s3 = boto3.client("s3")
BUCKET = os.environ["BUCKET"]
PREFIX = os.environ["PREFIX"].rstrip("/")

ROUTES = {
    "/": ("index.html", "text/html", False),
    "/index.html": ("index.html", "text/html", False),
    "/style.css": ("style.css", "text/css", False),
    "/cv.pdf": ("cv.pdf", "application/pdf", True),
}

NOT_FOUND_HTML = (
    "<!DOCTYPE html><html><head><title>404</title></head>"
    "<body><h1>404 - Not found</h1><p>This page does not exist.</p>"
    '<p><a href="/">Back to the CV</a></p></body></html>'
)


def get_object(name):
    return s3.get_object(Bucket=BUCKET, Key=f"{PREFIX}/{name}")["Body"].read()


def respond(status, body, content_type, binary=False, cache=False):
    headers = {"Content-Type": content_type}
    if cache:
        headers["Cache-Control"] = "max-age=60"
    return {
        "statusCode": status,
        "headers": headers,
        "body": base64.b64encode(body).decode("ascii") if binary else body,
        "isBase64Encoded": binary,
    }


def lambda_handler(event, context):
    start = time.time()
    path = event.get("rawPath") or "/"
    try:
        if path in ROUTES:
            name, content_type, binary = ROUTES[path]
            data = get_object(name)
            if name == "index.html":
                data = data.decode("utf-8").replace(
                    "{{HOSTED_ON}}", f"Lambda {context.function_name}"
                )
                result = respond(200, data, content_type, cache=True)
            else:
                result = respond(200, data, content_type, binary=binary)
            status = 200
        else:
            status = 404
            result = respond(404, NOT_FOUND_HTML, "text/html")
    except Exception:
        status = 500
        result = respond(500, "<h1>500 - Server error</h1>", "text/html")

    print(json.dumps({
        "fn": context.function_name,
        "path": path,
        "status": status,
        "ms": int((time.time() - start) * 1000),
    }))
    return result

"""Structured JSON request logging middleware."""

import logging
import time

from pythonjsonlogger import json as jsonlogger
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response


def configure_json_logging() -> None:
    """
    Configure root logger to emit structured JSON log records.

    :return: None
    """
    handler = logging.StreamHandler()
    formatter = jsonlogger.JsonFormatter(
        fmt="%(asctime)s %(levelname)s %(name)s %(message)s"
    )
    handler.setFormatter(formatter)
    root_logger = logging.getLogger()
    root_logger.handlers = [handler]
    root_logger.setLevel(logging.INFO)


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """
    Starlette middleware that logs every HTTP request as JSON.

    :ivar logger: Logger instance for request records
    """

    def __init__(self, app) -> None:
        """
        Initialise middleware and configure JSON logging.

        :param app: ASGI application
        """
        super().__init__(app)
        configure_json_logging()
        self.logger = logging.getLogger("ims.access")

    async def dispatch(
        self, request: Request, call_next
    ) -> Response:
        """
        Process request, log structured record, return response.

        :param request: Incoming HTTP request
        :param call_next: Next middleware or route handler
        :return: HTTP response
        """
        start = time.monotonic()
        response = await call_next(request)
        duration_ms = round((time.monotonic() - start) * 1000, 2)

        self.logger.info(
            "request",
            extra={
                "method": request.method,
                "path": request.url.path,
                "status_code": response.status_code,
                "duration_ms": duration_ms,
            },
        )
        return response

function handler(event) {
    var r = event.request;
    var path = r.uri.slice(4);
    var allowed = /^\/(health|protocol|profile|leaderboard|auth\/(login|register|logout-all)|matchmaking\/rooms\/(join|cancel)|parties(\/(current|accept|reserve|ready|reset))?)\/?$/;
    if (!allowed.test(path)) return {statusCode:404,headers:{"content-type":{value:"application/json"},"cache-control":{value:"no-store"}},body:'{"detail":"Not found"}'};
    r.uri = path;
    r.headers["x-forwarded-for"] = {value:event.viewer.ip};
    return r;
  }

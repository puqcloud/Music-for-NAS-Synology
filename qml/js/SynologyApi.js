.pragma library

// Synology Audio REST Web API Client for Ubuntu Touch

function cleanUrl(url) {
    if (!url) return "";
    var u = url.trim();
    if (!u.match(/^https?:\/\//i)) {
        u = "https://" + u;
    }
    return u.replace(/\/+$/, "");
}

function getErrorMessage(code) {
    switch (code) {
        case 100: return "Unknown error occurred.";
        case 101: return "Invalid parameter provided.";
        case 102: return "The requested API does not exist on this Synology NAS.";
        case 103: return "The requested API method does not exist.";
        case 104: return "This API version is not supported by your DSM.";
        case 105: return "User does not have permission to execute this API.";
        case 106: return "Session timeout. Please log in again.";
        case 107: return "Session interrupted by duplicate login.";
        case 119: return "Session expired (119). Please log in again.";
        case 400: return "No such account or incorrect password.";
        case 401: return "Account is disabled or locked.";
        case 402: return "Permission denied. Check Synology Audio app privileges.";
        case 403: return "2-Step verification (OTP) code is required.";
        case 404: return "Invalid 2-Step verification (OTP) code.";
        case 405: return "App-specific password required.";
        case 406: return "OTP enforcement is active for this account.";
        case 407: return "Max login attempts reached. Please try again later.";
        case 408: return "Password expired. Please change it in DSM.";
        case 409: return "Password is too weak.";
        case 500: return "Synology server internal error.";
        case 801: return "Team Space is not enabled or accessible.";
        default: return "Synology error code: " + code;
    }
}

function sendRequest(url, method, params, headers, callback) {
    var xhr = new XMLHttpRequest();
    var paramPairs = [];
    if (params) {
        for (var k in params) {
            if (params.hasOwnProperty(k) && params[k] !== undefined && params[k] !== null) {
                paramPairs.push(encodeURIComponent(k) + "=" + encodeURIComponent(params[k]));
            }
        }
    }
    var fullUrl = url;
    var postData = null;

    if (method.toUpperCase() === "GET") {
        if (paramPairs.length > 0) {
            fullUrl += (url.indexOf("?") === -1 ? "?" : "&") + paramPairs.join("&");
        }
    } else {
        postData = paramPairs.join("&");
    }

    xhr.open(method, fullUrl, true);
    xhr.timeout = 25000;

    if (method.toUpperCase() === "POST") {
        xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded; charset=UTF-8");
    }

    if (headers) {
        for (var h in headers) {
            if (headers.hasOwnProperty(h) && headers[h]) {
                xhr.setRequestHeader(h, headers[h]);
            }
        }
    }

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status >= 200 && xhr.status < 300) {
                try {
                    var json = JSON.parse(xhr.responseText);
                    if (json.success) {
                        callback(null, json.data);
                    } else {
                        var errCode = (json.error && json.error.code) ? json.error.code : 100;
                        var errMsg = getErrorMessage(errCode);
                        callback({ code: errCode, message: errMsg, raw: json.error }, null);
                    }
                } catch(e) {
                    callback({ code: -1, message: "Failed to parse JSON response: " + e.message, raw: xhr.responseText }, null);
                }
            } else if (xhr.status === 0) {
                callback({ code: 0, message: "Network connection failed or host unreachable. Check URL and SSL settings." }, null);
            } else {
                callback({ code: xhr.status, message: "HTTP error: " + xhr.status + " " + xhr.statusText }, null);
            }
        }
    };

    xhr.ontimeout = function() {
        callback({ code: -2, message: "Connection timed out. Please check your network and NAS address." }, null);
    };

    xhr.onerror = function() {
        callback({ code: 0, message: "Network error occurred." }, null);
    };

    xhr.send(postData);
}

// 1. Query Synology API Info
function queryApiInfo(serverUrl, callback) {
    var base = cleanUrl(serverUrl);
    var url = base + "/webapi/query.cgi";
    var params = {
        api: "SYNO.API.Info",
        version: 1,
        method: "query",
        query: "all"
    };
    sendRequest(url, "GET", params, null, callback);
}

// 2. Login to Synology DSM
function login(serverUrl, account, password, otpCode, callback) {
    var base = cleanUrl(serverUrl);
    var url = base + "/webapi/entry.cgi";
    var params = {
        api: "SYNO.API.Auth",
        version: 7,
        method: "login",
        account: account,
        passwd: password,
        format: "sid",
        session: "AudioStation",
        enable_syno_token: "yes"
    };

    if (otpCode && otpCode.trim().length > 0) {
        params["otp_code"] = otpCode.trim();
    }

    sendRequest(url, "GET", params, null, function(err, data) {
        if (err && (err.code === 104 || err.code === 103)) {
            // Fallback to version 6
            params.version = 6;
            sendRequest(url, "GET", params, null, function(err2, data2) {
                if (err2 && (err2.code === 104 || err2.code === 103)) {
                    // Fallback to version 3
                    params.version = 3;
                    sendRequest(url, "GET", params, null, callback);
                } else {
                    callback(err2, data2);
                }
            });
        } else {
            callback(err, data);
        }
    });
}

// 3. Logout
function logout(serverUrl, sid, synotoken, callback) {
    var base = cleanUrl(serverUrl);
    var url = base + "/webapi/entry.cgi";
    var params = {
        api: "SYNO.API.Auth",
        version: 7,
        method: "logout",
        _sid: sid
    };
    var headers = {};
    if (synotoken) headers["X-SYNO-TOKEN"] = synotoken;

    sendRequest(url, "GET", params, headers, function(err, data) {
        if (callback) callback(err, data);
    });
}

// 4. Fetch Songs list
function getSongs(serverUrl, sid, synotoken, offset, limit, filters, callback) {
    var cb = callback;
    var filts = filters;
    if (typeof filters === "function") {
        cb = filters;
        filts = null;
    }
    
    var base = cleanUrl(serverUrl);
    // Based on Synology API Info, SYNO.AudioStation.Song requires AudioStation/song.cgi
    var url = base + "/webapi/AudioStation/song.cgi";
    var postData = {
        api: "SYNO.AudioStation.Song",
        version: 3,
        method: "list",
        library: "shared",
        offset: offset || 0,
        limit: limit || 1000,
        sort_by: "title",
        sort_direction: "ASC",
        additional: "song_tag,song_audio,song_rating",
        _sid: sid
    };
    
    if (filts) {
        for (var k in filts) {
            if (filts.hasOwnProperty(k)) {
                postData[k] = filts[k];
            }
        }
    }
    
    var headers = {};
    if (synotoken) headers["X-SYNO-TOKEN"] = synotoken;

    sendRequest(url, "POST", postData, headers, cb);
}


// 5. Fetch Albums list
function getAlbums(serverUrl, sid, synotoken, offset, limit, callback) {
    var base = cleanUrl(serverUrl);
    var url = base + "/webapi/AudioStation/album.cgi";
    var postData = {
        api: "SYNO.AudioStation.Album",
        version: 3,
        method: "list",
        library: "shared",
        offset: offset || 0,
        limit: limit || 100,
        additional: "album_cover,album_artist",
        _sid: sid
    };
    var headers = {};
    if (synotoken) headers["X-SYNO-TOKEN"] = synotoken;

    sendRequest(url, "POST", postData, headers, callback);
}

// 5b. Fetch Artists list
function getArtists(serverUrl, sid, synotoken, offset, limit, callback) {
    var base = cleanUrl(serverUrl);
    var url = base + "/webapi/AudioStation/artist.cgi";
    var postData = {
        api: "SYNO.AudioStation.Artist",
        version: 4,
        method: "list",
        library: "shared",
        offset: offset || 0,
        limit: limit || 100,
        _sid: sid
    };
    var headers = {};
    if (synotoken) headers["X-SYNO-TOKEN"] = synotoken;

    sendRequest(url, "POST", postData, headers, callback);
}

// 5c. Fetch Composers list
function getComposers(serverUrl, sid, synotoken, offset, limit, callback) {
    var base = cleanUrl(serverUrl);
    var url = base + "/webapi/AudioStation/composer.cgi";
    var postData = {
        api: "SYNO.AudioStation.Composer",
        version: 2,
        method: "list",
        library: "shared",
        offset: offset || 0,
        limit: limit || 100,
        _sid: sid
    };
    var headers = {};
    if (synotoken) headers["X-SYNO-TOKEN"] = synotoken;

    sendRequest(url, "POST", postData, headers, callback);
}

// 5d. Fetch Genres list
function getGenres(serverUrl, sid, synotoken, offset, limit, callback) {
    var base = cleanUrl(serverUrl);
    var url = base + "/webapi/AudioStation/genre.cgi";
    var postData = {
        api: "SYNO.AudioStation.Genre",
        version: 3,
        method: "list",
        library: "shared",
        offset: offset || 0,
        limit: limit || 100,
        _sid: sid
    };
    var headers = {};
    if (synotoken) headers["X-SYNO-TOKEN"] = synotoken;

    sendRequest(url, "POST", postData, headers, callback);
}

// 6. Fetch Folders list
// Newer DSM exposes SYNO.AudioStation.Folder via AudioStation/folder.cgi and
// returns data.items; older DSM may expose SYNO.AudioStation.Browse.Folder via
// entry.cgi returning data.folders. Both are normalized to data.folders so
// callers always get the same shape.
function getFolders(serverUrl, sid, synotoken, offset, limit, callback) {
    var base = cleanUrl(serverUrl);
    var headers = {};
    if (synotoken) headers["X-SYNO-TOKEN"] = synotoken;

    var newParams = {
        api: "SYNO.AudioStation.Folder",
        version: 1,
        method: "list",
        offset: offset || 0,
        limit: limit || 50,
        sort_by: "title",
        sort_direction: "ASC",
        _sid: sid
    };
    var oldParams = {
        api: "SYNO.AudioStation.Browse.Folder",
        version: 1,
        method: "list",
        offset: offset || 0,
        limit: limit || 50,
        _sid: sid
    };

    sendRequest(base + "/webapi/AudioStation/folder.cgi", "GET", newParams, headers, function(err, data) {
        if (!err && data) {
            callback(null, { folders: data.items || [] });
            return;
        }
        if (err && (err.code === 102 || err.code === 103)) {
            sendRequest(base + "/webapi/entry.cgi", "GET", oldParams, headers, callback);
            return;
        }
        callback(err, null);
    });
}

// 6b. Get a single folder by ID
var _folderNameCache = {};
function getFolderById(serverUrl, sid, synotoken, folderId, callback) {
    if (_folderNameCache[folderId]) {
        callback(null, _folderNameCache[folderId]);
        return;
    }
    getFolders(serverUrl, sid, synotoken, 0, 500, function(err, data) {
        if (err) {
            callback(err, null);
            return;
        }
        var folders = data ? (data.folders || []) : [];
        for (var i = 0; i < folders.length; i++) {
            if (folders[i].id === folderId) {
                var name = folders[i].title || folders[i].name || folderId;
                _folderNameCache[folderId] = name;
                callback(null, name);
                return;
            }
        }
        callback({ code: 100, message: "Folder not found" }, null);
    });
}

function clearFolderCache() {
    _folderNameCache = {};
}



// 7. Generate Cover URL (for Albums/Songs/Artists/Composers)
function getCoverUrl(serverUrl, sid, synotoken, type, name, artist) {
    var base = cleanUrl(serverUrl);
    var url = base + "/webapi/AudioStation/cover.cgi?api=SYNO.AudioStation.Cover&version=3&method=getcover&library=shared&_sid=" + encodeURIComponent(sid);
    if (synotoken) {
        url += "&SynoToken=" + encodeURIComponent(synotoken);
    }
    if (type === "album") {
        url += "&album_name=" + encodeURIComponent(name || "");
        if (artist) url += "&album_artist_name=" + encodeURIComponent(artist);
    } else if (type === "artist") {
        url += "&artist_name=" + encodeURIComponent(name || "");
    } else if (type === "composer") {
        url += "&composer_name=" + encodeURIComponent(name || "");
    } else if (type === "song") {
        url += "&type=song&id=" + encodeURIComponent(name || "");
    }
    return url;
}

// 8. Generate Stream URL (for playing songs)
function getStreamUrl(serverUrl, sid, synotoken, songId) {
    var base = cleanUrl(serverUrl);
    var url = base + "/webapi/AudioStation/stream.cgi/0.mp3?api=SYNO.AudioStation.Stream&version=2&method=stream&_sid=" + encodeURIComponent(sid) + "&id=" + encodeURIComponent(songId);
    if (synotoken) url += "&SynoToken=" + encodeURIComponent(synotoken);
    url += "&_dc=" + new Date().getTime();
    return url;
}

// 9. Search Items (Songs)
function searchItems(serverUrl, sid, synotoken, keyword, offset, limit, callback) {
    var base = cleanUrl(serverUrl);
    var url = base + "/webapi/entry.cgi";
    var params = {
        api: "SYNO.AudioStation.Search.Search",
        version: 1,
        method: "list_item",
        keyword: JSON.stringify(keyword),
        offset: offset || 0,
        limit: limit || 100,
        additional: '["thumbnail","resolution","orientation"]',
        _sid: sid
    };
    var headers = {};
    if (synotoken) headers["X-SYNO-TOKEN"] = synotoken;

    sendRequest(url, "GET", params, headers, callback);
}

// 10. Generate Download URL for offline caching
function getDownloadUrl(serverUrl, sid, synotoken, songId) {
    var base = cleanUrl(serverUrl);
    var url = base + "/webapi/AudioStation/stream.cgi/0.mp3?api=SYNO.AudioStation.Stream&version=2&method=stream&_sid=" + encodeURIComponent(sid) + "&id=" + encodeURIComponent(songId);
    if (synotoken) url += "&SynoToken=" + encodeURIComponent(synotoken);
    return url;
}

// DownloadManager.js — handles offline caching of songs
// Uses FileHelper (C++ context property) for file I/O

var ENABLE_DEBUG = false; // Set to true only during development

function log(msg) {
    if (ENABLE_DEBUG) {
        console.log("[DownloadManager] " + msg);
    }
}

// Sanitize server-provided ids before using them in file names so they
// can never escape the cache directory (path traversal protection).
function safeId(songId) {
    var s = String(songId === undefined || songId === null ? "" : songId);
    s = s.replace(/[^0-9a-zA-Z\-_]/g, "");
    return s || "unknown";
}

// Never log session credentials: strip _sid / SynoToken parameters.
function redactUrl(url) {
    return String(url).replace(/([?&])(_sid|SynoToken)=[^&]*/g, "$1$2=REDACTED");
}

function getDownloadPath(songId) {
    return FileHelper.cacheDir() + "/" + safeId(songId) + ".mp3";
}

function isDownloaded(songId) {
    var path = getDownloadPath(songId);
    return FileHelper.fileExists(path);
}

function getDownloadedFileSize(songId) {
    var path = getDownloadPath(songId);
    if (!FileHelper.fileExists(path)) return 0;
    return FileHelper.fileSize(path);
}

function downloadSong(serverUrl, sid, synotoken, songId, title, artist, progressCallback, finishedCallback) {
    var destPath = getDownloadPath(songId);

    if (FileHelper.fileExists(destPath)) {
        if (finishedCallback) finishedCallback(true, destPath, 0);
        return;
    }

    var downloadUrl = serverUrl.replace(/\/+$/, "") + "/webapi/AudioStation/stream.cgi/0.mp3"
        + "?api=SYNO.AudioStation.Stream&version=2&method=stream"
        + "&_sid=" + encodeURIComponent(sid)
        + "&id=" + encodeURIComponent(songId);
    if (synotoken) downloadUrl += "&SynoToken=" + encodeURIComponent(synotoken);

    var xhr = new XMLHttpRequest();
    xhr.open("GET", downloadUrl, true);
    xhr.responseType = "arraybuffer";
    xhr.timeout = 600000; // 10 minutes for large files

    xhr.onprogress = function(e) {
        if (progressCallback && e.lengthComputable) {
            progressCallback(e.loaded, e.total);
        }
    };

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            log("Download XHR DONE. Status: " + xhr.status + " for URL: " + redactUrl(downloadUrl));
            if (xhr.status === 200) {
                var responseSize = xhr.response ? xhr.response.byteLength : 0;
                log("Received response size: " + responseSize + " bytes.");
                var ok = FileHelper.writeFile(destPath, xhr.response);
                log("FileHelper.writeFile result: " + ok);
                if (finishedCallback) finishedCallback(ok, destPath, responseSize, ok ? 0 : -1);
            } else {
                log("Download failed with status: " + xhr.status);
                if (finishedCallback) finishedCallback(false, "", 0, xhr.status);
            }
        }
    };

    xhr.onerror = function() {
        log("Download XHR Error fired.");
        if (finishedCallback) finishedCallback(false, "", 0, 0);
    };

    xhr.ontimeout = function() {
        log("Download XHR Timeout fired.");
        if (finishedCallback) finishedCallback(false, "", 0, -2);
    };

    xhr.send();
}

function getCoverPath(songId) {
    return FileHelper.cacheDir() + "/cover_" + safeId(songId) + ".jpg";
}

function hasCover(songId) {
    return FileHelper.fileExists(getCoverPath(songId));
}

function downloadCover(serverUrl, sid, synotoken, songId, callback) {
    var destPath = getCoverPath(songId);
    if (FileHelper.fileExists(destPath)) {
        if (callback) callback(true, destPath);
        return;
    }
    
    var coverUrl = serverUrl.replace(/\/+$/, "") + "/webapi/AudioStation/cover.cgi"
        + "?api=SYNO.AudioStation.Cover&version=3&method=getcover&library=shared"
        + "&_sid=" + encodeURIComponent(sid)
        + "&type=song"
        + "&id=" + encodeURIComponent(songId);
    if (synotoken) coverUrl += "&SynoToken=" + encodeURIComponent(synotoken);
    
    var xhr = new XMLHttpRequest();
    xhr.open("GET", coverUrl, true);
    xhr.responseType = "arraybuffer";
    xhr.timeout = 30000;
    
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200 && xhr.response) {
                var ok = FileHelper.writeFile(destPath, xhr.response);
                if (callback) callback(ok, destPath);
            } else {
                if (callback) callback(false, "");
            }
        }
    };
    xhr.onerror = function() { if (callback) callback(false, ""); };
    xhr.ontimeout = function() { if (callback) callback(false, ""); };
    xhr.send();
}

function deleteDownloadedSong(songId) {
    var path = getDownloadPath(songId);
    var cover = getCoverPath(songId);
    if (FileHelper.fileExists(cover)) {
        FileHelper.deleteFile(cover);
    }
    if (FileHelper.fileExists(path)) {
        return FileHelper.deleteFile(path);
    }
    return true;
}

function getDownloadedSongsList() {
    var dir = FileHelper.cacheDir();
    var files = FileHelper.listFiles(dir, ["*.mp3"]);
    var result = [];
    for (var i = 0; i < files.length; i++) {
        var fileName = files[i];
        var songId = fileName.replace(/\.mp3$/, "");
        var filePath = dir + "/" + fileName;
        var size = FileHelper.fileSize(filePath);
        result.push({
            id: songId,
            path: filePath,
            size: size
        });
    }
    return result;
}

function formatSize(bytes) {
    if (bytes < 1024) return bytes + " B";
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB";
    return (bytes / (1024 * 1024)).toFixed(1) + " MB";
}

function getTotalCacheSize() {
    var dir = FileHelper.cacheDir();
    var files = FileHelper.listFiles(dir, ["*.mp3", "*.jpg"]);
    var total = 0;
    for (var i = 0; i < files.length; i++) {
        total += FileHelper.fileSize(dir + "/" + files[i]);
    }
    return total;
}

function clearAllDownloads() {
    var dir = FileHelper.cacheDir();
    var files = FileHelper.listFiles(dir, ["*.mp3", "*.jpg"]);
    for (var i = 0; i < files.length; i++) {
        FileHelper.deleteFile(dir + "/" + files[i]);
    }
    return true;
}

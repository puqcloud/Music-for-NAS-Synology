#include "filehelper.h"
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QStandardPaths>
#include <QDebug>
#include <QVariant>

FileHelper::FileHelper(QObject *parent)
    : QObject(parent)
{
}

// Defense in depth: refuse any file operation whose resolved path
// escapes the application cache directory (blocks path traversal attempts).
bool FileHelper::isSafeCachePath(const QString &path)
{
    QString cDir = cacheDir();
    QString cache = QFileInfo(cDir).canonicalFilePath();
    if (cache.isEmpty()) {
        cache = QDir::cleanPath(cDir);
    }
    if (cache.isEmpty()) {
        return false;
    }
    QString cleaned = QDir::cleanPath(path);
    QString target = QFileInfo(cleaned).canonicalFilePath();
    if (target.isEmpty()) {
        target = QFileInfo(cleaned).absoluteFilePath();
    }
    return target.startsWith(cache + "/") || target == cache;
}

bool FileHelper::fileExists(const QString &path)
{
    if (!isSafeCachePath(path)) {
        return false;
    }
    return QFileInfo::exists(path);
}

bool FileHelper::writeFile(const QString &path, const QVariant &data)
{
    if (!isSafeCachePath(path)) {
        qWarning() << "FileHelper: refusing to write outside cache dir:" << path;
        return false;
    }

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly)) {
        qWarning() << "FileHelper: cannot write" << path;
        return false;
    }
    
    QByteArray bytes;
    if (data.type() == QVariant::ByteArray) {
        bytes = data.toByteArray();
    } else {
        bytes = data.toString().toUtf8();
    }
    
    qint64 written = file.write(bytes);
    file.close();
    return written == bytes.size();
}

QByteArray FileHelper::readFile(const QString &path)
{
    if (!isSafeCachePath(path)) {
        qWarning() << "FileHelper: refusing to read outside cache dir:" << path;
        return QByteArray();
    }

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "FileHelper: cannot read" << path;
        return QByteArray();
    }
    QByteArray data = file.readAll();
    file.close();
    return data;
}

bool FileHelper::deleteFile(const QString &path)
{
    if (!isSafeCachePath(path)) {
        qWarning() << "FileHelper: refusing to delete outside cache dir:" << path;
        return false;
    }
    return QFile::remove(path);
}

qint64 FileHelper::fileSize(const QString &path)
{
    if (!isSafeCachePath(path)) {
        return 0;
    }
    QFileInfo info(path);
    return info.size();
}

QString FileHelper::cacheDir()
{
    QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/cache";
    QDir().mkpath(dir);
    return dir;
}

bool FileHelper::mkdir(const QString &path)
{
    if (!isSafeCachePath(path)) {
        qWarning() << "FileHelper: refusing to mkdir outside cache dir:" << path;
        return false;
    }
    return QDir().mkpath(path);
}

QStringList FileHelper::listFiles(const QString &dir, const QStringList &nameFilters)
{
    if (!isSafeCachePath(dir)) {
        qWarning() << "FileHelper: refusing to list outside cache dir:" << dir;
        return QStringList();
    }
    QDir d(dir);
    return d.entryList(nameFilters, QDir::Files, QDir::Name);
}

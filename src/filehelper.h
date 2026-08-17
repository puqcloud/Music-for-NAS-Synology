#ifndef FILEHELPER_H
#define FILEHELPER_H

#include <QObject>
#include <QString>
#include <QByteArray>

class FileHelper : public QObject
{
    Q_OBJECT

public:
    explicit FileHelper(QObject *parent = nullptr);

    Q_INVOKABLE bool fileExists(const QString &path);
    Q_INVOKABLE bool writeFile(const QString &path, const QVariant &data);
    Q_INVOKABLE QByteArray readFile(const QString &path);
    Q_INVOKABLE bool deleteFile(const QString &path);
    Q_INVOKABLE qint64 fileSize(const QString &path);
    Q_INVOKABLE QString cacheDir();
    Q_INVOKABLE bool mkdir(const QString &path);
    Q_INVOKABLE QStringList listFiles(const QString &dir, const QStringList &nameFilters);

private:
    bool isSafeCachePath(const QString &path);
};

#endif // FILEHELPER_H

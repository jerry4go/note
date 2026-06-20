@echo off
chcp 65001 >nul
set "work_dir=D:\02-MarkDown文档"
cd /d "%work_dir%" || (
    echo 错误：目录不存在 %work_dir%
    pause
    exit /b 1
)

echo 拉取GitHub远程更新
git pull origin main

echo 扫描全部文件变更
git add .

:: 判断是否存在未提交改动
git status --porcelain
if "%errorlevel%"=="0" (
    echo 检测到文件变更，开始提交推送
) else (
    echo 未检测到文件修改，同步结束
    pause
    exit
)

git commit -m "auto sync %date% %time%"
echo 推送文件到GitHub
git push origin main
echo ======================
echo 全部同步完成！
pause
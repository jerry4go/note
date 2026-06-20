@echo off
chcp 65001 >nul
set "work_dir=D:\02-MarkDown文档"
cd /d "%work_dir%" || exit /b 1
git pull origin main
git add .
git status --porcelain
if errorlevel 1 exit
git commit -m "auto sync %date% %time%"
git push origin main
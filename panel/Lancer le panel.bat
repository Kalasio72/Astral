@echo off
title Astral Panel
cd /d "%~dp0"
if not exist node_modules (
	echo Installation des dependances...
	call npm install --omit=dev
)
start "" http://127.0.0.1:8420
node server.mjs
pause

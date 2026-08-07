@echo off
rem Pembungkus biar peserta Windows ga usah ngurusin ExecutionPolicy.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0lab.ps1" %*

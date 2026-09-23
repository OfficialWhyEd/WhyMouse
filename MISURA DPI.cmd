@echo off
title Misura DPI del mouse
powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0misura-dpi.ps1"

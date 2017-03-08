call "C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\Common7\Tools\VsDevCmd.bat"
python.exe ../configure.py --sdks="tf2" --hl2sdk-root="C:\sdkfolder" --sm-path="C:\sdkfolder\sourcemod" --mms-path="C:\sdkfolder\mmsource-1.10"
ambuild
pause
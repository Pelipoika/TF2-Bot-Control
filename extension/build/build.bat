call "C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\Common7\Tools\VsDevCmd.bat" -arch=x86 -host_arch=x86 -app_platform=Desktop -no_logo
python ../configure.py --sdks="tf2" --hl2sdk-root="C:\sdkfolder" --sm-path="C:\sdkfolder\sourcemod" --mms-path="C:\sdkfolder\mmsource-1.10"
pause
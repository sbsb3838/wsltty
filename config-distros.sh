#! /bin/sh

PATH=/bin:$PATH

contextmenu=false
remove=false
alldistros=true
config=true

case "`basename $0`" in
wsl*)
  config=false;;
esac

case "$1" in
-info)
  config=false
  shift;;
-shortcuts-remove)
  remove=true
  shift;;
-contextmenu)
  contextmenu=true
  shift;;
-contextmenu-default)
  contextmenu=true
  alldistros=false
  shift;;
-contextmenu-remove)
  contextmenu=true
  remove=true
  direckey='/HKEY_CURRENT_USER/Software/Classes/Directory'

  regtool list "$direckey/shell" 2>/dev/null |
  while read name
  do
    case `regtool get "$direckey/shell/$name/command/"` in
    *bin\\mintty.exe*/bin/wslbridge*|*bin\\mintty.exe*--WSL*)
      regtool remove "$direckey/shell/$name/command"
      regtool remove "$direckey/shell/$name"
      ;;
    esac
  done

  regtool list "$direckey/Background/shell" 2>/dev/null |
  while read name
  do
    case `regtool get "$direckey/Background/shell/$name/command/"` in
    *bin\\mintty.exe*/bin/wslbridge*|*bin\\mintty.exe*--WSL*)
      regtool remove "$direckey/Background/shell/$name/command"
      regtool remove "$direckey/Background/shell/$name"
      ;;
    esac
  done
  exit
  shift;;
esac

# test w/o WSL: call this script with REGTOOLFAKE=true dash config-distros.sh
if ${REGTOOLFAKE:-false}
then
regtool () {
  case "$1" in
  -*)  shift;;
  esac
  key=`echo $2 | sed -e 's,.*{\(.*\)}.*,\1,' -e t -e d`
  case "$1.$2" in
  list.*)
        if $contextmenu
        then  echo "{0}"
        else  echo "{1}"; echo "{2}"
        fi;;
  get.*/DistributionName)
        echo "distro$key";;
  get.*/BasePath)
        echo "C:\\Program\\{$key}\\State";;
  get.*/PackageFamilyName)
        echo "distro{$key}";;
  get.*/PackageFullName)
        echo "C:\\Program\\{$key}";;
  esac
}
fi

# dash built-in echo enforces interpretation of \t etc
echoc () {
  cmd /c echo $*
}

if $config
then while read line; do echo "$line"; done <</EOB > mkbat.bat
@echo off
echo Creating %1.bat

echo @echo off> %1.bat
echo rem Start mintty terminal for WSL package %name% in current directory>> %1.bat
echo %target% -i "%icon%" %minttyargs% %bridgeargs%>> %1.bat
/EOB
fi

PATH=/bin:$PATH

lxss="/HKEY_CURRENT_USER/Software/Microsoft/Windows/CurrentVersion/Lxss"
schema="/HKEY_CURRENT_USER/Software/Classes/Local Settings/Software/Microsoft/Windows/CurrentVersion/AppModel/SystemAppData"

#(regtool list "$lxss" 2>/dev/null && echo || echo "No WSL packages registered" >&2) |
(
  if $alldistros
  then  regtool list "$lxss" 2>/dev/null
  else  true
  fi && echo || echo "No WSL packages registered" >&2) |
while read guid
do
  ok=false
  case $guid in
  {*)
    distro=`regtool get "$lxss/$guid/DistributionName"`
    case "$distro" in
    Legacy)
    	name="Bash on Windows"
    	launch=
    	launcher="$SYSTEMROOT/System32/bash.exe"
    	;;
    *)	name="$distro"
    	launch="$distro"
    	launcher="$LOCALAPPDATA/Microsoft/WindowsApps/$distro.exe"
    	;;
    esac
    basepath=`regtool get "$lxss/$guid/BasePath"`
    if package=`regtool -q get "$lxss/$guid/PackageFamilyName"`
    then
    	instdir=`regtool get "$schema/$package/Schemas/PackageFullName"`
    	if [ -r "$ProgramW6432/WindowsApps/$instdir/images/icon.ico" ]
    	then	icon="%PROGRAMFILES%/WindowsApps/$instdir/images/icon.ico"
    	else	icon="%LOCALAPPDATA%/wsltty/wsl.ico"
    	fi
    	root="$basepath/rootfs"
    else
    	icon="%LOCALAPPDATA%/lxss/bash.ico"
    	root="$basepath"
    fi

    minttyargs='--wsl --rootfs="'"$root"'" --configdir="%APPDATA%\wsltty" -o Locale=C -o Charset=UTF-8 /bin/wslbridge '
    minttyargs='--WSL="'"$distro"'" --configdir="%APPDATA%\wsltty"'
    #if [ -z "$launch" ]
    #then	bridgeargs='-t /bin/bash'
    #else	bridgeargs='-l "'"$launch"'" -t /bin/bash'
    #fi
    bridgeargs='--distro-guid "'"$guid"'" -t /bin/bash'
    bridgeargs='--distro-guid "'"$guid"'" -t'

    ok=true;;
  "")	# WSL default installation
    distro=
    name=WSL
    icon="%LOCALAPPDATA%/wsltty/wsl.ico"
    minttyargs='--WSL= --configdir="%APPDATA%\wsltty"'
    bridgeargs='-t'

    ok=true;;
  esac
  echoc "distro '$distro'"
  echoc "- name '$name'"
  echoc "- guid $guid"
  echoc "- (launcher $launcher)"
  echoc "- icon $icon"
  echoc "- root $root"
  target='%LOCALAPPDATA%\wsltty\bin\mintty.exe'
  bridgeargs=" "

  if $ok && $config
  then
    export target minttyargs bridgeargs icon

    if $contextmenu
    then
      # context menu entries
      #cmd /C mkcontext "$name"
      direckey='HKEY_CURRENT_USER\Software\Classes\Directory'
      if $remove
      then
        reg delete "$direckey\\shell\\$name" /f
        reg delete "$direckey\\Background\\shell\\$name" /f
      else
        reg add "$direckey\\shell\\$name" /d "$name Terminal" /f
        reg add "$direckey\\shell\\$name" /v Icon /d "$icon" /f
        cmd /C reg add "$direckey\\shell\\$name\\command" /d "\"$target\" -i \"$icon\" --dir \"%1\" $minttyargs $bridgeargs" /f
        reg add "$direckey\\Background\\shell\\$name" /d "$name Terminal" /f
        reg add "$direckey\\Background\\shell\\$name" /v Icon /d "$icon" /f
        cmd /C reg add "$direckey\\Background\\shell\\$name\\command" /d "\"$target\" -i \"$icon\" $minttyargs $bridgeargs" /f
      fi
    else
      # invocation shortcuts and scripts
      if $remove
      then
        cmd /C del "%APPDATA%\\Microsoft\\Windows\\Start Menu\\Programs\\$name Terminal.lnk"
        cmd /C del "%LOCALAPPDATA%\\Microsoft\\WindowsApps\\$name.bat"
        cmd /C del "%LOCALAPPDATA%\\Microsoft\\WindowsApps\\$name~.bat"
      else
        # desktop shortcut in %USERPROFILE% -> Start Menu - WSLtty
        cscript /nologo mkshortcut.vbs "/name:$name Terminal %"
        cmd /C copy "$name Terminal %.lnk" "%APPDATA%\\Microsoft\\Windows\\Start Menu\\Programs\\WSLtty"

        # launch script in . -> WSLtty home, WindowsApps launch folder
        cmd /C mkbat.bat "$name"
        cmd /C copy "$name.bat" "%LOCALAPPDATA%\\wsltty\\$name.bat"
        cmd /C copy "$name.bat" "%LOCALAPPDATA%\\Microsoft\\WindowsApps\\$name.bat"

        # prepare versions to target WSL home directory
        #bridgeargs="-C~ $bridgeargs"
        minttyargs="$minttyargs -~"

        # desktop shortcut in ~ -> Start Menu
        cscript /nologo mkshortcut.vbs "/name:$name Terminal"
        cmd /C copy "$name Terminal.lnk" "%APPDATA%\\Microsoft\\Windows\\Start Menu\\Programs"

        # default desktop shortcut in ~ -> Desktop
        if [ "$name" = "WSL" ]
        then	cmd /C copy "$name Terminal.lnk" "%USERPROFILE%\\Desktop"
        fi

        # launch script in ~ -> WSLtty home, WindowsApps launch folder
        cmd /C mkbat.bat "$name~"
        cmd /C copy "$name~.bat" "%LOCALAPPDATA%\\wsltty\\$name~.bat"
        cmd /C copy "$name~.bat" "%LOCALAPPDATA%\\Microsoft\\WindowsApps\\$name~.bat"
      fi

    fi
  fi
done

for _d in /opt/homebrew/opt /usr/local/opt; do
  for _p in grep gnu-sed coreutils findutils; do
    [ -d "$_d/$_p/libexec/gnubin" ] && PATH="$_d/$_p/libexec/gnubin:$PATH"
  done
  [ -x "$_d/bash/bin/bash" ] && PATH="$_d/bash/bin:$PATH"
done
export PATH; unset _d _p

## Bootstrap

```bash
mapfile rc < <(find . -mindepth 1 -maxdepth 1 -name ".*" -not -name ".git*" -not -name ".config" -printf "%f\n" && find .config .shortcuts .termux -type f)
for file in "${rc[@]}"; do file="$(tr -d '[:cntrl:]' <<< "${file}")"
    [[ -d "$(dirname "${HOME}/${file}")" ]] && {
        echo -ne "\033[2K\033[1GSymbolic link: ${file}"
        ln -sf "$(pwd)/${file}" "${HOME}/${file}"
    }
done && unset rc
```

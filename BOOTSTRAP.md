## Bootstrap

```bash
for rc in $(find . -mindepth 1 -maxdepth 1 -name ".*" -not -name ".git*" -not -name ".config"); do
    ln -sf "$(pwd)/$(basename "${rc}")" ~/
done
```

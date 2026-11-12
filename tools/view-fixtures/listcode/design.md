# Design: listcode

## Architecture

1. Run the record step:

       sh render.sh spec/archive/<date>-verify-<slug> all

2. Then read it.

```text
example
~~~
```

Records live at spec/archive/<date>-verify-<slug>/.

## Interfaces
- **Record**: one directory per run

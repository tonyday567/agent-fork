# Load real session file with aeson

Run via:
```bash
cd ~/haskell/agent-fork && cabal repl
```

Then:

```haskell
import qualified Data.Aeson as A
import qualified Data.ByteString.Lazy as BL
import Data.Maybe (mapMaybe)

sessionFile = "/Users/tonyday567/.pi/agent/sessions/--Users-tonyday567-repos-pi-mono--/2026-02-03T18-04-45-234Z_467948cf-b477-4628-95be-c1d52178f004.jsonl"

content <- BL.readFile sessionFile
let lineList = BL.lines content
putStrLn $ "Total lines: " ++ show (length lineList)

let decoded = mapMaybe (A.decode @A.Value) lineList
putStrLn $ "Valid JSON: " ++ show (length decoded)

-- Print first entry
case decoded of
  (first:_) -> print first
  [] -> putStrLn "No valid JSON"
```

Expected: 142 lines, 142 valid JSON, first entry is session header.

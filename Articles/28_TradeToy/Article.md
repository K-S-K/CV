# Trading Toy tool

[Back to the main page](../../README.md)

**Development period:** 2021.11-2021.11.

**Practical application:** The weekend project[^1].

**Project purpose:** Research on some trading algorithms

**Project description:**
The program connects to the exchange, listens to trade signals, analyzes price trends, and emulates buy and sell operations. It downloads real-time trading history into a SQL database and can replay it through a built-in exchange emulator — so algorithms can be tested on historical data without real capital at risk. The user switches between the live exchange and the emulator with a single setting.

**Implementation technologies:** .NET 5, WPF, Binance.Net library by JKorf, T-SQL, and some domain knowledge.

![The trading session emulation with 'naive' order completion](Images/01_TT_RetroGraph.gif)

[^1]: It is sometimes necessary to program something for yourself. To keep the knowledge in the actual state. To have something "good made" because it's made by yourself on the computer. To avoid hate evolving to the profession. And, of course, just for fun. Currently, the project is not evolving because Binance strictly recommends that people with Russian passports live.

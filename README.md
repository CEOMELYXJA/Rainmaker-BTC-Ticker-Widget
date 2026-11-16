# Rainmaker-Bitcoin-Ticker-Widget

A compact Bitcoin price widget for Windows and the web. The project name uses “Rainmaker”; the Windows software is called **Rainmeter**.

## Windows: Rainmeter skin

Rainmeter is required for the Windows skin. Install it from [rainmeter.net](https://www.rainmeter.net/), then:

1. Download this repository using **Code → Download ZIP** and extract it.
2. Copy the `skin/BitcoinTicker` folder to `Documents/Rainmeter/Skins/BitcoinTicker`.
3. Open Rainmeter, select **Refresh all**, expand **BitcoinTicker**, and load `Bitcoin.ini`.

The skin uses Windows PowerShell to fetch prices and draw the graph. Its command starts PowerShell with a process-only execution policy bypass; it does not change your system-wide policy. Your network must allow requests to Coinbase. Local history and generated graph images are saved in the skin's `@Resources` folder; keep that folder writable. Refreshing or reloading the skin can request a new price immediately.

## Browser version

Open `index.html` in a modern browser, or use the GitHub Pages site if it has been enabled for this repository. Rainmeter is not required for the browser version. An internet connection is needed for prices. Browser storage must be enabled for history to persist; clearing site data removes it. Private browsing may discard history when closed. A browser may pause or delay updates in background tabs or while the device sleeps.

## How it works

- Both versions request BTC spot prices in USD and CAD from Coinbase approximately every five minutes while running. Prices can differ from other exchanges.
- Each currency is compared with its previous successfully observed price: green means up, red means down, and yellow means unchanged or no earlier observation. Failed requests do not create a sample. The displayed prices are rounded to whole dollars, while movement is calculated using the full quoted price, so a color can change even if the rounded number stays the same.
- The graph shows USD price changes over a rolling 12-hour window in five-minute slots. History starts collecting when the widget runs. Missing intervals remain gaps; prices are not invented or backfilled while the widget is closed or offline.
- History is stored separately for the Rainmeter skin and each browser/site origin. The two versions do not share their history.

## Credits and license

The original skin metadata credits **poiru** for the base and specifies **Creative Commons Attribution-NonCommercial-ShareAlike 3.0**. The skin layout and bundled illustro background retain that attribution and license. See [CC BY-NC-SA 3.0](https://creativecommons.org/licenses/by-nc-sa/3.0/) for its terms. The project is shared under those same terms; attribution must be preserved, commercial use is not permitted, and adaptations must be shared alike.



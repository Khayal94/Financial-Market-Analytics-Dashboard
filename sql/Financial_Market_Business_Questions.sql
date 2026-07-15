/*
=====================================================================
Financial Market Analytics Dashboard
SQL Business Questions
Database: MarketDataWarehouse
=====================================================================

Data Model:
- Instruments: Dimension table
- MarketPrices: Fact table
- Relationship: Instruments[Ticker] 1 -> many MarketPrices[Ticker]

Note:
Business Question 4 is intentionally exploratory. Volume is not directly
comparable across all asset classes because its meaning differs by market.
Business Question 5 provides the corrected stock-only comparison.
=====================================================================
*/

USE MarketDataWarehouse;
GO


/*====================================================================
BUSINESS QUESTION 1
How many market-price records exist for each asset class?

Business Purpose:
Validate that all asset classes were successfully loaded into SQL Server.
====================================================================*/

SELECT
    AssetType,
    COUNT(*) AS TotalRecords
FROM dbo.MarketPrices
GROUP BY AssetType
ORDER BY TotalRecords DESC;
GO


/*====================================================================
BUSINESS QUESTION 2
Which asset class has the highest average closing price?

Business Purpose:
Understand the different nominal price scales across asset classes.

Limitation:
A higher average price does not mean better performance or investment value.
====================================================================*/

SELECT
    AssetType,
    ROUND(AVG(ClosePrice), 2) AS AverageClosePrice
FROM dbo.MarketPrices
GROUP BY AssetType
ORDER BY AverageClosePrice DESC;
GO


/*====================================================================
BUSINESS QUESTION 3
Which individual instruments have the highest average closing prices?

Business Purpose:
Rank instruments by average nominal closing price and demonstrate the
relationship between the fact and dimension tables.

Limitation:
Nominal price is not the same as investment performance.
====================================================================*/

SELECT
    i.InstrumentName,
    mp.AssetType,
    ROUND(AVG(mp.ClosePrice), 2) AS AverageClosePrice
FROM dbo.MarketPrices AS mp
INNER JOIN dbo.Instruments AS i
    ON mp.Ticker = i.Ticker
GROUP BY
    i.InstrumentName,
    mp.AssetType
ORDER BY AverageClosePrice DESC;
GO


/*====================================================================
BUSINESS QUESTION 4
Which instruments have the highest total reported trading volume?

Business Purpose:
Explore reported trading activity across all instruments.

Important Limitation:
The query is technically correct, but volume definitions differ across
stocks, indices, commodities, Forex, and cryptocurrencies. Therefore,
the result should not be treated as a fair cross-asset liquidity ranking.
====================================================================*/

SELECT
    i.InstrumentName,
    mp.AssetType,
    SUM(mp.Volume) AS TotalVolume
FROM dbo.MarketPrices AS mp
INNER JOIN dbo.Instruments AS i
    ON mp.Ticker = i.Ticker
GROUP BY
    i.InstrumentName,
    mp.AssetType
ORDER BY TotalVolume DESC;
GO


/*====================================================================
BUSINESS QUESTION 5
Which stocks have the highest total trading volume?

Business Purpose:
Identify the most actively traded stocks using a comparable measure:
the total number of shares traded.
====================================================================*/

SELECT
    i.InstrumentName,
    SUM(mp.Volume) AS TotalVolume
FROM dbo.MarketPrices AS mp
INNER JOIN dbo.Instruments AS i
    ON mp.Ticker = i.Ticker
WHERE mp.AssetType = 'Stock'
GROUP BY i.InstrumentName
ORDER BY TotalVolume DESC;
GO


/*====================================================================
BUSINESS QUESTION 6
Which stock reached the highest closing price during the analyzed period?

Business Purpose:
Identify the maximum recorded closing price among the selected stocks.

Limitation:
A single peak price does not measure overall investment performance.
====================================================================*/

SELECT TOP (1)
    i.InstrumentName,
    MAX(mp.ClosePrice) AS HighestClosingPrice
FROM dbo.MarketPrices AS mp
INNER JOIN dbo.Instruments AS i
    ON mp.Ticker = i.Ticker
WHERE mp.AssetType = 'Stock'
GROUP BY i.InstrumentName
ORDER BY HighestClosingPrice DESC;
GO


/*====================================================================
BUSINESS QUESTION 7
Which stock had the highest percentage price return?

Business Purpose:
Compare stock performance fairly using the first and last available
closing prices during the analyzed period.

Limitation:
This is price return only. It excludes dividends, transaction costs,
risk, volatility, and other total-return components.
====================================================================*/

WITH RankedPrices AS
(
    SELECT
        mp.Ticker,
        i.InstrumentName,
        mp.[Date],
        mp.ClosePrice,
        ROW_NUMBER() OVER
        (
            PARTITION BY mp.Ticker
            ORDER BY mp.[Date] ASC
        ) AS FirstRow,
        ROW_NUMBER() OVER
        (
            PARTITION BY mp.Ticker
            ORDER BY mp.[Date] DESC
        ) AS LastRow
    FROM dbo.MarketPrices AS mp
    INNER JOIN dbo.Instruments AS i
        ON mp.Ticker = i.Ticker
    WHERE mp.AssetType = 'Stock'
),
FirstLastPrices AS
(
    SELECT
        Ticker,
        InstrumentName,
        MAX(CASE WHEN FirstRow = 1 THEN ClosePrice END) AS FirstClosePrice,
        MAX(CASE WHEN LastRow = 1 THEN ClosePrice END) AS LastClosePrice
    FROM RankedPrices
    GROUP BY
        Ticker,
        InstrumentName
)
SELECT
    InstrumentName,
    ROUND(FirstClosePrice, 2) AS FirstClosePrice,
    ROUND(LastClosePrice, 2) AS LastClosePrice,
    ROUND(
        ((LastClosePrice - FirstClosePrice) / NULLIF(FirstClosePrice, 0)) * 100,
        2
    ) AS PercentageReturn
FROM FirstLastPrices
ORDER BY PercentageReturn DESC;
GO


/*====================================================================
BUSINESS QUESTION 8
Which asset class has the highest raw price variability?

Business Purpose:
Use standard deviation to explore how widely closing prices are dispersed
within each asset class.

Important Limitation:
This is not a true apples-to-apples volatility comparison because each
asset class contains instruments with very different price levels.
For rigorous financial volatility, calculate standard deviation of returns
for each instrument and then compare those results.
====================================================================*/

SELECT
    AssetType,
    ROUND(STDEV(ClosePrice), 2) AS RawPriceVariability
FROM dbo.MarketPrices
GROUP BY AssetType
ORDER BY RawPriceVariability DESC;
GO


/*====================================================================
BUSINESS QUESTION 9
Which month had the highest stock trading activity?

Business Purpose:
Identify monthly patterns in equity trading activity while keeping the
volume unit comparable by analyzing stocks only.
====================================================================*/

SELECT
    MONTH([Date]) AS MonthNumber,
    DATENAME(MONTH, [Date]) AS MonthName,
    SUM(Volume) AS TotalStockTradingVolume
FROM dbo.MarketPrices
WHERE AssetType = 'Stock'
GROUP BY
    MONTH([Date]),
    DATENAME(MONTH, [Date])
ORDER BY TotalStockTradingVolume DESC;
GO


/*====================================================================
BUSINESS QUESTION 10
Stock Performance Summary Report

Business Purpose:
Create a business-ready report showing each stock's first price, last
price, percentage return, and total trading volume.
====================================================================*/

WITH RankedPrices AS
(
    SELECT
        mp.Ticker,
        i.InstrumentName,
        mp.[Date],
        mp.ClosePrice,
        mp.Volume,
        ROW_NUMBER() OVER
        (
            PARTITION BY mp.Ticker
            ORDER BY mp.[Date] ASC
        ) AS FirstRow,
        ROW_NUMBER() OVER
        (
            PARTITION BY mp.Ticker
            ORDER BY mp.[Date] DESC
        ) AS LastRow
    FROM dbo.MarketPrices AS mp
    INNER JOIN dbo.Instruments AS i
        ON mp.Ticker = i.Ticker
    WHERE mp.AssetType = 'Stock'
),
Performance AS
(
    SELECT
        Ticker,
        InstrumentName,
        MAX(CASE WHEN FirstRow = 1 THEN ClosePrice END) AS FirstPrice,
        MAX(CASE WHEN LastRow = 1 THEN ClosePrice END) AS LastPrice,
        SUM(Volume) AS TotalVolume
    FROM RankedPrices
    GROUP BY
        Ticker,
        InstrumentName
)
SELECT
    InstrumentName,
    ROUND(FirstPrice, 2) AS FirstPrice,
    ROUND(LastPrice, 2) AS LastPrice,
    ROUND(
        ((LastPrice - FirstPrice) / NULLIF(FirstPrice, 0)) * 100,
        2
    ) AS ReturnPercent,
    TotalVolume
FROM Performance
ORDER BY ReturnPercent DESC;
GO

-- CreateTable
CREATE TABLE "Token" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "ticker" TEXT NOT NULL,
    "projectName" TEXT,
    "primaryChain" TEXT,
    "coingeckoId" TEXT,
    "defillamaSlug" TEXT,
    "binanceSymbol" TEXT,
    "mexcSymbol" TEXT,
    "cluster" TEXT,
    "notes" TEXT,
    "collisionWarning" TEXT,
    "status" TEXT NOT NULL DEFAULT 'active',
    "localVersion" INTEGER NOT NULL DEFAULT 1,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL
);

-- CreateTable
CREATE TABLE "TokenDeployment" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "tokenId" INTEGER NOT NULL,
    "chain" TEXT NOT NULL,
    "contractAddress" TEXT,
    "isPrimaryLiquidity" BOOLEAN NOT NULL DEFAULT false,
    "notes" TEXT,
    CONSTRAINT "TokenDeployment_tokenId_fkey" FOREIGN KEY ("tokenId") REFERENCES "Token" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "Label" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "name" TEXT NOT NULL,
    "color" TEXT,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- CreateTable
CREATE TABLE "TokenLabel" (
    "tokenId" INTEGER NOT NULL,
    "labelId" INTEGER NOT NULL,
    "addedAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY ("tokenId", "labelId"),
    CONSTRAINT "TokenLabel_tokenId_fkey" FOREIGN KEY ("tokenId") REFERENCES "Token" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "TokenLabel_labelId_fkey" FOREIGN KEY ("labelId") REFERENCES "Label" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "MetricSnapshot" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "tokenId" INTEGER NOT NULL,
    "fetchedAt" DATETIME NOT NULL,
    "priceCoingecko" REAL,
    "priceDexscreener" REAL,
    "priceBinance" REAL,
    "priceMexc" REAL,
    "divergencePct" REAL,
    "marketCap" REAL,
    "fdv" REAL,
    "volume24h" REAL,
    "volumeToMcap" REAL,
    "change24hPct" REAL,
    "change7dPct" REAL,
    "change30dPct" REAL,
    "ath" REAL,
    "drawdownFromAthPct" REAL,
    "circulatingSupply" REAL,
    "totalSupply" REAL,
    "floatPct" REAL,
    "tvl" REAL,
    "tvlChange30dPct" REAL,
    "dataQuality" TEXT,
    "assessableHorizonsJson" TEXT,
    "gatingReason" TEXT,
    "rawJson" TEXT,
    CONSTRAINT "MetricSnapshot_tokenId_fkey" FOREIGN KEY ("tokenId") REFERENCES "Token" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "FetchRun" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "startedAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "finishedAt" DATETIME,
    "status" TEXT NOT NULL DEFAULT 'running',
    "tokensCount" INTEGER,
    "errorSummary" TEXT
);

-- CreateTable
CREATE TABLE "Catalyst" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "tokenId" INTEGER NOT NULL,
    "eventDate" DATETIME NOT NULL,
    "eventType" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "sizePctOfSupply" REAL,
    "sourceUrl" TEXT,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "Catalyst_tokenId_fkey" FOREIGN KEY ("tokenId") REFERENCES "Token" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "SheetSyncState" (
    "tokenId" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "sheetRow" INTEGER,
    "baseContentHash" TEXT,
    "lastSyncedAt" DATETIME,
    CONSTRAINT "SheetSyncState_tokenId_fkey" FOREIGN KEY ("tokenId") REFERENCES "Token" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "ConflictLog" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "tokenId" INTEGER NOT NULL,
    "detectedAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "field" TEXT NOT NULL,
    "localValue" TEXT,
    "sheetValue" TEXT,
    "resolution" TEXT NOT NULL,
    CONSTRAINT "ConflictLog_tokenId_fkey" FOREIGN KEY ("tokenId") REFERENCES "Token" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- CreateIndex
CREATE INDEX "Token_status_idx" ON "Token"("status");

-- CreateIndex
CREATE INDEX "Token_ticker_idx" ON "Token"("ticker");

-- CreateIndex
CREATE UNIQUE INDEX "Label_name_key" ON "Label"("name");

-- CreateIndex
CREATE INDEX "MetricSnapshot_tokenId_fetchedAt_idx" ON "MetricSnapshot"("tokenId", "fetchedAt");

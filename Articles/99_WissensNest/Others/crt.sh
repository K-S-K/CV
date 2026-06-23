#!/usr/bin/env bash

cd ../Src

rm -rf ./*

dotnet new sln --name MyAI
dotnet sln migrate MyAI.sln
rm MyAI.sln


dotnet new classlib -o Libraries/MyAI.Contracts
dotnet sln add Libraries/MyAI.Contracts/MyAI.Contracts.csproj
dotnet new classlib -o Libraries/MyAI.Persistent.SQLite
dotnet sln add Libraries/MyAI.Persistent.SQLite/MyAI.Persistent.SQLite.csproj
dotnet new classlib -o Libraries/MyAI.Ollama
dotnet sln add Libraries/MyAI.Ollama/MyAI.Ollama.csproj
dotnet new classlib -o Libraries/MyAI.Core
dotnet sln add Libraries/MyAI.Core/MyAI.Core.csproj
dotnet new classlib -o Libraries/MyAI.Client
dotnet sln add Libraries/MyAI.Client/MyAI.Client.csproj
dotnet new classlib -o Libraries/MyAI.WebSearch
dotnet sln add Libraries/MyAI.WebSearch/MyAI.WebSearch.csproj

dotnet new web -o Services/MyAI.API
dotnet sln add Services/MyAI.API/MyAI.API.csproj
dotnet new blazor -o Services/MyAI.UI
dotnet sln add Services/MyAI.UI/MyAI.UI.csproj

dotnet new xunit -o Tests/MyAI.UnitTests
dotnet sln add Tests/MyAI.UnitTests/MyAI.UnitTests.csproj
dotnet new xunit -o Tests/MyAI.IntegrationTests
dotnet sln add Tests/MyAI.IntegrationTests/MyAI.IntegrationTests.csproj

@echo "Projects created and added to solution."

@echo "Adding project references..."
dotnet add Libraries/MyAI.Persistent.SQLite/MyAI.Persistent.SQLite.csproj reference Libraries/MyAI.Contracts/MyAI.Contracts.csproj
dotnet add Libraries/MyAI.Ollama/MyAI.Ollama.csproj reference Libraries/MyAI.Contracts/MyAI.Contracts.csproj
dotnet add Libraries/MyAI.Core/MyAI.Core.csproj reference Libraries/MyAI.Contracts/MyAI.Contracts.csproj
dotnet add Libraries/MyAI.Client/MyAI.Client.csproj reference Libraries/MyAI.Contracts/MyAI.Contracts.csproj
dotnet add Libraries/MyAI.WebSearch/MyAI.WebSearch.csproj reference Libraries/MyAI.Contracts/MyAI.Contracts.csproj
dotnet add Services/MyAI.API/MyAI.API.csproj reference Libraries/MyAI.Core/MyAI.Core.csproj
dotnet add Services/MyAI.API/MyAI.API.csproj reference Libraries/MyAI.Ollama/MyAI.Ollama.csproj
dotnet add Services/MyAI.API/MyAI.API.csproj reference Libraries/MyAI.Client/MyAI.Client.csproj
dotnet add Services/MyAI.API/MyAI.API.csproj reference Libraries/MyAI.WebSearch/MyAI.WebSearch.csproj
dotnet add Services/MyAI.API/MyAI.API.csproj reference Libraries/MyAI.Persistent.SQLite/MyAI.Persistent.SQLite.csproj
dotnet add Services/MyAI.UI/MyAI.UI.csproj reference Libraries/MyAI.Client/MyAI.Client.csproj

@echo "Adding NuGet packages..."
dotnet add Libraries/MyAI.Ollama/MyAI.Ollama.csproj package OllamaSharp
dotnet add Libraries/MyAI.Ollama/MyAI.Ollama.csproj package Microsoft.Extensions.Options
dotnet add Libraries/MyAI.Persistent.SQLite/MyAI.Persistent.SQLite.csproj package Microsoft.EntityFrameworkCore.Sqlite
dotnet add Libraries/MyAI.Persistent.SQLite/MyAI.Persistent.SQLite.csproj package Microsoft.EntityFrameworkCore.Design
dotnet add Libraries/MyAI.WebSearch/MyAI.WebSearch.csproj package Microsoft.Extensions.Hosting.Abstractions
dotnet add Libraries/MyAI.Core/MyAI.Core.csproj package Microsoft.Extensions.Hosting.Abstractions
dotnet add Services/MyAI.API/MyAI.API.csproj package Microsoft.EntityFrameworkCore.Design
dotnet add Libraries/MyAI.Client/MyAI.Client.csproj package Microsoft.Extensions.Http

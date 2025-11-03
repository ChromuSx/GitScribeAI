# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GitScribeAI is a Windows batch script tool that automatically generates Git commit messages using OpenAI's API. It analyzes staged Git changes and produces conventional commit messages in multiple languages (English and Italian).

## Architecture

### Core Components

**GitScribeAI.bat** (GitScribeAI.bat:1)
The main executable batch script that orchestrates the entire workflow:
1. Configuration loading (from INI file or environment variables)
2. Git diff extraction from staged changes
3. OpenAI API interaction via embedded PowerShell
4. Commit message generation and clipboard management
5. Optional automatic commit execution

**Configuration System** (GitScribeAI.bat:14-21)
- Priority hierarchy: CLI arguments > Config file > Defaults
- Config file: `gitscribeai_config.ini` (excluded from git via .gitignore)
- Sample config: `gitscribeai_config.sample.ini` (empty template)
- Environment variable support for `OPENAI_API_KEY`

**API Integration** (GitScribeAI.bat:90-91)
- Inline PowerShell script for HTTP requests to OpenAI
- Single-line command with complex escaping for Batch compatibility
- Uses System.Net.WebClient for API calls
- Error handling via PowerShell try/catch redirected to temp files

## Key Technical Details

### Batch Script Patterns

**DelayedExpansion** (GitScribeAI.bat:2)
The script uses `setlocal EnableDelayedExpansion` to allow variable expansion with `!VAR!` syntax within loops and conditional blocks. This is critical for dynamic variable handling in Batch.

**Temporary File Management** (GitScribeAI.bat:58-59)
Creates unique temp directories using `%TEMP%\gitscribeai_%RANDOM%` to avoid conflicts. All temp files are cleaned up in the `:cleanup` label (GitScribeAI.bat:176-178).

**PowerShell Embedding** (GitScribeAI.bat:90)
The script embeds a complete PowerShell command as a single line to:
- Read the git diff file
- Construct JSON request body
- Make authenticated HTTPS POST request
- Parse JSON response
- Extract commit message

### Configuration Loading

**INI Parser** (GitScribeAI.bat:160-174)
Custom Batch-based INI parser using `for /f` loops:
- Filters comments (lines starting with `#`)
- Splits on `=` delimiter
- Dynamically sets variables based on parameter names
- Handles whitespace trimming

### Prompts and Localization

**Language-Specific Prompts** (GitScribeAI.bat:76-85)
Prompts are hardcoded in the batch file for each supported language. To add a new language, add a new conditional branch in this section following the existing pattern.

## Common Development Tasks

### Testing Changes

Since this is a Batch script without formal tests, manually test by:
1. Staging some changes: `git add <file>`
2. Running the script: `GitScribeAI.bat`
3. Testing with options: `GitScribeAI.bat --lang italian --model gpt-4o`
4. Testing config creation: `GitScribeAI.bat --create-config`

### Modifying the API Request

The PowerShell command at GitScribeAI.bat:90 is complex due to escaping requirements. When modifying:
- Test PowerShell logic separately first
- Be careful with quote escaping (`'` inside `"..."`)
- Variable substitution uses `%VAR%` (Batch) not `$VAR` (PowerShell)
- JSON depth parameter may need adjustment for complex payloads

### Adding New Languages

1. Add language check in GitScribeAI.bat:76-85
2. Define appropriate prompt in target language
3. Update help text in GitScribeAI.bat:134
4. Update README.md with new language support

### Security Considerations

- The `gitscribeai_config.ini` file is gitignored to prevent API key leakage
- API key priority: Environment variable > Config file
- Never commit the actual config file with real API keys
- Sample config intentionally has empty OPENAI_API_KEY field

## File Structure

```
GitScribeAI/
├── GitScribeAI.bat              # Main executable
├── gitscribeai_config.sample.ini # Empty config template
├── gitscribeai_config.ini       # User config (gitignored)
├── .gitignore                   # Excludes config file
├── README.md                    # User documentation
├── LICENSE                      # MIT License
└── logo.png                     # Project logo
```

## OpenAI API Configuration

**Default Model**: `gpt-4o` (GitScribeAI.bat:9)

**API Endpoint**: `https://api.openai.com/v1/chat/completions` (GitScribeAI.bat:90)

**Request Format**: Chat completions with single user message containing prompt + diff

**Response Parsing**: Extracts `response.choices[0].message.content` from JSON

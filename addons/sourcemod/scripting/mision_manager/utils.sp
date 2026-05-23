SMCError MM_ParseValveFsFile(SMCParser parser, const char[] path, int &line = 0, int &col = 0)
{
	File file = OpenFile(path, "rt", true);
	if (file == null)
	{
		return SMCError_StreamOpen;
	}

	int fileSize = file.Size();
	if (fileSize < 0)
	{
		delete file;
		return SMCError_StreamError;
	}

	if (fileSize >= MM_MAX_MISSION_FILE_SIZE)
	{
		MM_DebugLog("ParseValveFsFile path=%s rejected size=%d max=%d", path, fileSize, MM_MAX_MISSION_FILE_SIZE - 1);
		delete file;
		return SMCError_StreamError;
	}

	char fileContents[MM_MAX_MISSION_FILE_SIZE];
	int bytesRead = file.ReadString(fileContents, sizeof(fileContents), fileSize);
	delete file;

	if (bytesRead < 0)
	{
		return SMCError_StreamError;
	}

	bytesRead = MM_SanitizeMissionContents(fileContents, bytesRead);
	fileContents[bytesRead] = '\0';
	MM_DebugLog("ParseValveFsFile path=%s size=%d bytesRead=%d", path, fileSize, bytesRead);
	return parser.ParseString(fileContents, line, col);
}

bool MM_TryGetLocalizedPhrase(const char[] phrase, int client, char[] output, int length)
{
	if (MM_TryResolveManagedLocalization(phrase, client, output, length))
	{
		return true;
	}

	strcopy(output, length, phrase);
	return false;
}

bool MM_TryResolveManagedLocalization(const char[] phrase, int client, char[] output, int length)
{
	if (g_hMissionManagerLocalizer == null || !g_hMissionManagerLocalizer.IsReady())
	{
		return false;
	}

	char mapCode[MAX_MAP_CODE_LENGTH];
	if (Campaign_ExtractMapCode(phrase, mapCode, sizeof(mapCode)))
	{
		return Chapter_GetLocalizedName(phrase, client, output, length, g_hMissionManagerLocalizer);
	}

	if (Campaign_GetLocalizedNameFromMapCode(phrase, client, output, length, g_hMissionManagerLocalizer))
	{
		return true;
	}

	return false;
}

int MM_FindNextSignificantLineStart(const char[] buffer, int position, int length)
{
	while (position < length)
	{
		int lineEnd = position;
		while (lineEnd < length && buffer[lineEnd] != '\n')
		{
			lineEnd++;
		}

		int firstNonWhitespace = position;
		while (firstNonWhitespace < lineEnd
			&& (buffer[firstNonWhitespace] == ' ' || buffer[firstNonWhitespace] == '\t' || buffer[firstNonWhitespace] == '\r'))
		{
			firstNonWhitespace++;
		}

		if (firstNonWhitespace < lineEnd)
		{
			if (!(buffer[firstNonWhitespace] == '/' && firstNonWhitespace + 1 < lineEnd && buffer[firstNonWhitespace + 1] == '/'))
			{
				return firstNonWhitespace;
			}
		}

		position = (lineEnd < length && buffer[lineEnd] == '\n') ? lineEnd + 1 : lineEnd;
	}

	return -1;
}

bool MM_IsQuotedSectionNameOnlyLine(const char[] buffer, int lineStart, int lineEnd)
{
	int firstNonWhitespace = lineStart;
	while (firstNonWhitespace < lineEnd
		&& (buffer[firstNonWhitespace] == ' ' || buffer[firstNonWhitespace] == '\t' || buffer[firstNonWhitespace] == '\r'))
	{
		firstNonWhitespace++;
	}

	if (firstNonWhitespace >= lineEnd || buffer[firstNonWhitespace] != '"')
	{
		return false;
	}

	int readPos = firstNonWhitespace + 1;
	while (readPos < lineEnd)
	{
		if (buffer[readPos] == '"' && buffer[readPos - 1] != '\\')
		{
			readPos++;
			break;
		}

		readPos++;
	}

	if (readPos > lineEnd)
	{
		return false;
	}

	while (readPos < lineEnd)
	{
		if (buffer[readPos] == ' ' || buffer[readPos] == '\t' || buffer[readPos] == '\r')
		{
			readPos++;
			continue;
		}

		if (buffer[readPos] == '/' && readPos + 1 < lineEnd && buffer[readPos + 1] == '/')
		{
			return true;
		}

		return false;
	}

	return true;
}

int MM_SanitizeMissionContents(char[] buffer, int length)
{
	int writePos = 0;
	int lineStart = 0;

	while (lineStart < length)
	{
		int lineEnd = lineStart;
		while (lineEnd < length && buffer[lineEnd] != '\n')
		{
			lineEnd++;
		}

		bool hasNewLine = lineEnd < length && buffer[lineEnd] == '\n';
		int firstNonWhitespace = lineStart;
		while (firstNonWhitespace < lineEnd
			&& (buffer[firstNonWhitespace] == ' ' || buffer[firstNonWhitespace] == '\t' || buffer[firstNonWhitespace] == '\r'))
		{
			firstNonWhitespace++;
		}

		if (MM_IsQuotedSectionNameOnlyLine(buffer, lineStart, lineEnd))
		{
			int nextSignificantLineStart = MM_FindNextSignificantLineStart(buffer, hasNewLine ? lineEnd + 1 : lineEnd, length);
			if (nextSignificantLineStart == -1 || buffer[nextSignificantLineStart] == '}')
			{
				MM_DebugLog("SanitizeMissionContents dropped dangling section header before closing brace at offset=%d", lineStart);
				lineStart = hasNewLine ? lineEnd + 1 : lineEnd;
				continue;
			}
		}

		bool inQuotes = false;
		int closingBracePos = -1;
		for (int readPos = lineStart; readPos < lineEnd; readPos++)
		{
			char ch = buffer[readPos];
			if (ch == '"' && (readPos == lineStart || buffer[readPos - 1] != '\\'))
			{
				inQuotes = !inQuotes;
				continue;
			}

			if (!inQuotes && ch == '}')
			{
				closingBracePos = readPos;
				break;
			}
		}

		if (closingBracePos != -1)
		{
			for (int readPos = lineStart; readPos < firstNonWhitespace; readPos++)
			{
				buffer[writePos++] = buffer[readPos];
			}

			buffer[writePos++] = '}';
			if (hasNewLine)
			{
				buffer[writePos++] = '\n';
			}

			lineStart = hasNewLine ? lineEnd + 1 : lineEnd;
			continue;
		}

		inQuotes = false;
		for (int readPos = lineStart; readPos < lineEnd; readPos++)
		{
			char ch = buffer[readPos];
			if (ch == '"' && (readPos == lineStart || buffer[readPos - 1] != '\\'))
			{
				inQuotes = !inQuotes;
			}

			if (!inQuotes && ch == '/' && readPos + 1 < lineEnd && buffer[readPos + 1] == '/')
			{
				break;
			}

			buffer[writePos++] = ch;
		}

		if (hasNewLine)
		{
			buffer[writePos++] = '\n';
		}

		lineStart = hasNewLine ? lineEnd + 1 : lineEnd;
	}

	return writePos;
}

int String_ToLower(const char[] input, char[] output, int size)
{
	size--;
	int x = 0;
	while (input[x] != '\0' && x < size)
	{
		output[x] = CharToLower(input[x]);
		x++;
	}
	output[x] = '\0';

	return x + 1;
}


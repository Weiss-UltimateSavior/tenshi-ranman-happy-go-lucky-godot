#include <windows.h>
#include <shellapi.h>
#include <stdio.h>
#include <wchar.h>

#define TARGET_EXE L"tenshin_hgl.exe"
#define LOG_FILE L"japanese_maintenance_launcher.log"

static void write_log(const wchar_t *game_dir, const wchar_t *message) {
    wchar_t path[MAX_PATH];
    FILE *file = NULL;
    SYSTEMTIME now;

    swprintf_s(path, MAX_PATH, L"%s\\%s", game_dir, LOG_FILE);
    if (_wfopen_s(&file, path, L"a, ccs=UTF-8") != 0 || file == NULL) {
        return;
    }
    GetLocalTime(&now);
    fwprintf(file, L"[%04u-%02u-%02u %02u:%02u:%02u] %s\n",
        now.wYear, now.wMonth, now.wDay, now.wHour, now.wMinute, now.wSecond, message);
    fclose(file);
}

static BOOL append_quoted_argument(wchar_t *command, size_t capacity, const wchar_t *argument) {
    size_t used = wcslen(command);
    size_t length = wcslen(argument);

    if (used + length + 4 >= capacity) {
        return FALSE;
    }
    wcscat_s(command, capacity, L" \"");
    wcscat_s(command, capacity, argument);
    wcscat_s(command, capacity, L"\"");
    return TRUE;
}

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE previous, PWSTR command_line, int show_command) {
    wchar_t game_dir[MAX_PATH];
    wchar_t target_path[MAX_PATH];
    wchar_t command[32768];
    wchar_t message[1024];
    wchar_t *last_separator;
    LPWSTR *arguments;
    int argument_count;
    STARTUPINFOW startup = {0};
    PROCESS_INFORMATION process = {0};

    (void)instance;
    (void)previous;
    (void)command_line;
    (void)show_command;

    if (GetModuleFileNameW(NULL, game_dir, MAX_PATH) == 0) {
        MessageBoxW(NULL, L"ランチャーの起動場所を取得できませんでした。", L"天神乱漫 Happy Go Lucky!!", MB_OK | MB_ICONERROR);
        return 1;
    }
    last_separator = wcsrchr(game_dir, L'\\');
    if (last_separator == NULL) {
        MessageBoxW(NULL, L"ゲームディレクトリを取得できませんでした。", L"天神乱漫 Happy Go Lucky!!", MB_OK | MB_ICONERROR);
        return 1;
    }
    *last_separator = L'\0';
    swprintf_s(target_path, MAX_PATH, L"%s\\%s", game_dir, TARGET_EXE);

    if (GetFileAttributesW(target_path) == INVALID_FILE_ATTRIBUTES) {
        write_log(game_dir, L"ERROR: tenshin_hgl.exe was not found beside the launcher.");
        MessageBoxW(NULL, L"tenshin_hgl.exe がランチャーと同じフォルダにありません。", L"天神乱漫 Happy Go Lucky!!", MB_OK | MB_ICONERROR);
        return 1;
    }

    swprintf_s(command, sizeof(command) / sizeof(command[0]), L"\"%s\"", target_path);
    arguments = CommandLineToArgvW(GetCommandLineW(), &argument_count);
    if (arguments != NULL) {
        for (int index = 1; index < argument_count; ++index) {
            if (!append_quoted_argument(command, sizeof(command) / sizeof(command[0]), arguments[index])) {
                LocalFree(arguments);
                write_log(game_dir, L"ERROR: command line is too long.");
                MessageBoxW(NULL, L"起動オプションが長すぎます。", L"天神乱漫 Happy Go Lucky!!", MB_OK | MB_ICONERROR);
                return 1;
            }
        }
        LocalFree(arguments);
    }

    startup.cb = sizeof(startup);
    if (!CreateProcessW(target_path, command, NULL, NULL, FALSE, 0, NULL, game_dir, &startup, &process)) {
        DWORD error = GetLastError();
        swprintf_s(message, sizeof(message) / sizeof(message[0]), L"ERROR: CreateProcessW failed (%lu).", error);
        write_log(game_dir, message);
        MessageBoxW(NULL, L"日文维护版を起動できませんでした。\n詳細は japanese_maintenance_launcher.log を確認してください。", L"天神乱漫 Happy Go Lucky!!", MB_OK | MB_ICONERROR);
        return 1;
    }

    swprintf_s(message, sizeof(message) / sizeof(message[0]), L"STARTED: original Kirikiri process %lu.", process.dwProcessId);
    write_log(game_dir, message);
    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
    return 0;
}

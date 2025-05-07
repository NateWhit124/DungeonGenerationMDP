#include "juliaGD.h"

#define print UtilityFunctions::print
#define printerr UtilityFunctions::printerr
#define stdprint(x) std::cout << x << std::endl
#define BUFSIZE 4096

using namespace godot;
//extern __declspec(dllimport) jl_options_t jl_options;

JuliaMDP::JuliaMDP() {

}

JuliaMDP::~JuliaMDP() {
    if (piProcInfo.hProcess) CloseHandle(piProcInfo.hProcess);
    if (piProcInfo.hThread) CloseHandle(piProcInfo.hThread);
    if (juliaStd_OUT_Wr) CloseHandle(juliaStd_OUT_Wr);
    if (juliaStd_IN_Rd) CloseHandle(juliaStd_IN_Rd);
    if (juliaStd_IN_Wr) CloseHandle(juliaStd_IN_Wr);
    if (juliaStd_OUT_Rd) CloseHandle(juliaStd_OUT_Rd);
}

void JuliaMDP::_bind_methods() {
	ClassDB::bind_method(D_METHOD("send_to_julia", "msg"), &JuliaMDP::send_to_julia);
	ClassDB::bind_method(D_METHOD("read_from_julia"), &JuliaMDP::read_from_julia);
	ClassDB::bind_method(D_METHOD("create_random_dungeon"), &JuliaMDP::create_random_dungeon);
}

void JuliaMDP::_ready() {
	init_julia();
    stdprint("FINISHED _READY");
}

void JuliaMDP::init_julia() {
    printf("\n->Start of parent execution.\n");

    // Set the bInheritHandle flag so pipe handles are inherited. 

    saAttr.nLength = sizeof(SECURITY_ATTRIBUTES);
    saAttr.bInheritHandle = TRUE;
    saAttr.lpSecurityDescriptor = NULL;

    // Create a pipe for the child process's STDOUT. 

    if (!CreatePipe(&juliaStd_OUT_Rd, &juliaStd_OUT_Wr, &saAttr, 0))
        ErrorExit(TEXT("StdoutRd CreatePipe"));

    // Ensure the read handle to the pipe for STDOUT is not inherited.

    if (!SetHandleInformation(juliaStd_OUT_Rd, HANDLE_FLAG_INHERIT, 0))
        ErrorExit(TEXT("Stdout SetHandleInformation"));

    // Create a pipe for the child process's STDIN. 

    if (!CreatePipe(&juliaStd_IN_Rd, &juliaStd_IN_Wr, &saAttr, 0))
        ErrorExit(TEXT("Stdin CreatePipe"));

    // Ensure the write handle to the pipe for STDIN is not inherited. 

    if (!SetHandleInformation(juliaStd_IN_Wr, HANDLE_FLAG_INHERIT, 0))
        ErrorExit(TEXT("Stdin SetHandleInformation"));

    // Create the child process. 

    create_julia_child();
}

void JuliaMDP::send_to_julia(String msg)    
{
    BOOL bSuccess = FALSE;
    LPCVOID chBuf = msg.utf8().ptr();
    DWORD to_write = static_cast<DWORD>(msg.utf8().size() - 1);
    DWORD written = 0;

    stdprint("HERE IN send_to_julia");
    bSuccess = WriteFile(juliaStd_IN_Wr, chBuf, to_write, &written, NULL);
    if (!bSuccess)
        ErrorExit(TEXT("send_to_julia WriteFile"));
    stdprint("Successfully sent to julia");
    // Close the pipe handle so the child process stops reading. 
    //if (!CloseHandle(juliaStd_IN_Wr))
    //    ErrorExit(TEXT("StdInWr CloseHandle"));
}

String JuliaMDP::read_from_julia()

// Read output from the child process's pipe for STDOUT
// and write to the parent process's pipe for STDOUT. 
// Stop when there is no more data. 
{
    DWORD dwRead, dwWritten;
    CHAR chBuf[BUFSIZE];
    BOOL bSuccess = FALSE;
    HANDLE hParentStdOut = GetStdHandle(STD_OUTPUT_HANDLE);

    stdprint("HERE IN read_from_julia");
    //stdprint("we still here huh...");
    bSuccess = ReadFile(juliaStd_OUT_Rd, chBuf, BUFSIZE, &dwRead, NULL);

    stdprint("Recieved from Julia: ");
    bSuccess = WriteFile(hParentStdOut, chBuf,
        dwRead, &dwWritten, NULL);
    return String::utf8(chBuf, dwRead);
}

void JuliaMDP::ErrorExit(PCTSTR lpszFunction)

// Format a readable error message, display a message box, 
// and exit from the application.
{
    LPVOID lpMsgBuf;
    LPVOID lpDisplayBuf;
    DWORD dw = GetLastError();

    FormatMessage(
        FORMAT_MESSAGE_ALLOCATE_BUFFER |
        FORMAT_MESSAGE_FROM_SYSTEM |
        FORMAT_MESSAGE_IGNORE_INSERTS,
        NULL,
        dw,
        MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
        (LPTSTR)&lpMsgBuf,
        0, NULL);

    lpDisplayBuf = (LPVOID)LocalAlloc(LMEM_ZEROINIT,
        (lstrlen((LPCTSTR)lpMsgBuf) + lstrlen((LPCTSTR)lpszFunction) + 40) * sizeof(TCHAR));
    StringCchPrintf((LPTSTR)lpDisplayBuf,
        LocalSize(lpDisplayBuf) / sizeof(TCHAR),
        TEXT("%s failed with error %d: %s"),
        lpszFunction, dw, lpMsgBuf);
    MessageBox(NULL, (LPCTSTR)lpDisplayBuf, TEXT("Error"), MB_OK);

    LocalFree(lpMsgBuf);
    LocalFree(lpDisplayBuf);
    ExitProcess(1);
}

void JuliaMDP::create_julia_child() {
    TCHAR szCmdline[] = TEXT(
        "\"..\\..\\julia_runtime\\bin\\julia.exe\" "
        "--sysimage=\"..\\..\\julia_runtime\\my_sysimage.so\" "
        "--project=\"..\\..\\julia_runtime\\scripts\" "
        "-i \"..\\..\\julia_runtime\\scripts\\handler.jl\""
    );
    STARTUPINFO siStartInfo;
    BOOL bSuccess = FALSE;

    // Set up members of the PROCESS_INFORMATION structure. 

    ZeroMemory(&piProcInfo, sizeof(PROCESS_INFORMATION));

    // Set up members of the STARTUPINFO structure. 
    // This structure specifies the STDIN and STDOUT handles for redirection.

    ZeroMemory(&siStartInfo, sizeof(STARTUPINFO));
    siStartInfo.cb = sizeof(STARTUPINFO);
    siStartInfo.hStdError = juliaStd_OUT_Wr;
    siStartInfo.hStdOutput = juliaStd_OUT_Wr;
    siStartInfo.hStdError = juliaStd_OUT_Wr;
    siStartInfo.hStdInput = juliaStd_IN_Rd;
    siStartInfo.dwFlags |= STARTF_USESTDHANDLES;

    // Create the child process. 

    bSuccess = CreateProcess(NULL,
        szCmdline,     // command line 
        NULL,          // process security attributes 
        NULL,          // primary thread security attributes 
        TRUE,          // handles are inherited 
        0,             // creation flags 
        NULL,          // use parent's environment 
        NULL,          // use parent's current directory 
        &siStartInfo,  // STARTUPINFO pointer 
        &piProcInfo);  // receives PROCESS_INFORMATION 

    // If an error occurs, exit the application. 
    if (!bSuccess)
        ErrorExit(TEXT("CreateProcess"));
    else
    {
        // Close handles to the child process and its primary thread.
        // Some applications might keep these handles to monitor the status
        // of the child process, for example. 

        CloseHandle(piProcInfo.hProcess);
        CloseHandle(piProcInfo.hThread);

        // Close handles to the stdin and stdout pipes no longer needed by the child process.
        // If they are not explicitly closed, there is no way to recognize that the child process has ended.

        CloseHandle(juliaStd_OUT_Wr);
        CloseHandle(juliaStd_IN_Rd);
    }
}

String godot::JuliaMDP::create_random_dungeon()
{
    send_to_julia("create_random_dungeon()\n");
    return read_from_julia();
}

String godot::JuliaMDP::create_dungeon()
{
    send_to_julia("create_dungeon()\n");
    return read_from_julia();
}

String JuliaMDP::init_MDP(String mdp_json) {
	return "not implemented";
}
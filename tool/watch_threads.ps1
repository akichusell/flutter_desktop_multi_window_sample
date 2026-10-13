# Windows용. 앱 프로세스의 스레드 수와 메모리를 1초마다 찍는다. Ctrl+C로 끝낸다.
# 서브 창을 열고 닫으면서 REUSE_WINDOWS=true/false의 차이를 본다.
#   tool\watch_threads.bat
#
# 스레드는 시작 함수가 들어 있는 DLL별로 나눠 센다.
#   flutter_windows   Flutter 엔진 + Dart VM
#   nvwgf2umx 등      GPU 드라이버 (ANGLE → Direct3D 11)
#   ntdll             Windows 스레드 풀 워커

Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class ThreadStart {
  [DllImport("kernel32.dll")] static extern IntPtr OpenThread(int access, bool inherit, int id);
  [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
  [DllImport("ntdll.dll")] static extern int NtQueryInformationThread(IntPtr handle, int infoClass, out IntPtr info, int length, IntPtr returnLength);

  // ProcessThread.StartAddress는 모든 스레드가 ntdll로 나오므로 실제 시작 함수 주소를 직접 묻는다.
  public static long Of(int threadId) {
    IntPtr handle = OpenThread(0x0040, false, threadId); // THREAD_QUERY_INFORMATION
    if (handle == IntPtr.Zero) return 0;
    IntPtr address;
    NtQueryInformationThread(handle, 9, out address, IntPtr.Size, IntPtr.Zero); // ThreadQuerySetWin32StartAddress
    CloseHandle(handle);
    return address.ToInt64();
  }
}
"@

function Get-ThreadsByModule($p) {
  $modules = foreach ($m in $p.Modules) {
    $base = $m.BaseAddress.ToInt64()
    [pscustomobject]@{ Name = [IO.Path]::GetFileNameWithoutExtension($m.ModuleName); Base = $base; End = $base + $m.ModuleMemorySize }
  }
  $names = foreach ($t in $p.Threads) {
    $address = [ThreadStart]::Of($t.Id)
    $module = $modules | Where-Object { $address -ge $_.Base -and $address -lt $_.End } | Select-Object -First 1
    if ($module) { $module.Name } else { '?' }
  }
  ($names | Group-Object | Sort-Object @{ e = 'Count'; Descending = $true }, Name | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ' '
}

while ($true) {
  $p = Get-Process multi_window_sample -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($p) {
    "{0:HH:mm:ss}  threads={1}  ws={2:N0}MB  | {3}" -f (Get-Date), $p.Threads.Count, ($p.WorkingSet64 / 1MB), (Get-ThreadsByModule $p)
  }
  Start-Sleep 1
}

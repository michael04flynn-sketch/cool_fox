@echo off
setlocal EnableExtensions DisableDelayedExpansion
rem Play-VIctory.cmd with less of the card's memory used, for 4-8 GB cards.
rem Everything else is that launcher's: the checks, Series X, the measured
rem defaults. Any VICTORY_... variable set before this runs is kept.
rem
rem Title buffers of 4 MiB and up get a copy on the card (Play-VIctory.cmd:
rem 64 KiB and up), and those copies hold at most 256 MiB (the default on a
rem card of 12 GB or less is 512 MiB). See card_limits in shadow.rs.
if not defined VICTORY_CARD_BUFFERS_MIN_KB set "VICTORY_CARD_BUFFERS_MIN_KB=4096"
if not defined VICTORY_CARD_BUFFERS_MB set "VICTORY_CARD_BUFFERS_MB=256"
rem The driver's background shader recompiles off (host.rs).
if not defined VICTORY_D3D12_BACKGROUND set "VICTORY_D3D12_BACKGROUND=0"
rem Still out of memory: VICTORY_CONSOLE=series-s, at the price of the faces
rem of people in the world (Play-VIctory.cmd says why).
call "%~dp0Play-VIctory.cmd" %*
exit /b %errorlevel%

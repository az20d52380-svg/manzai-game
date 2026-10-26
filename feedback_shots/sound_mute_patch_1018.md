# 10/18 15:10 定期の回の見つけ物（未コミット・別セッション稼働中のため見送り）
- playtest_v7 の「MZ_YEARS 起動が30秒〜数分真っ白」の原因：年送りの計算ではない（CPU 0%）。
  sample でメインスレッドが WeekMainView の onAppear → Sound.bgm → AVAudioPlayer.prepareToPlay → AudioQueuePrime（音声サーバ待ち）で止まっていた。
  無人のシミュレータ（音の出力先なし）での現象。実機で起きるかは未確認。
- 直し案：sound_mute_patch_1018.diff（DEBUG のみ・MZ_* フック使用時は音を鳴らさない・MZ_SOUND=1 で鳴らす）。preview-all に当てて build→MZ_YEARS=5 で白画面が消えるか確認→コミット。
- 本番側の備え（判断不要・任意）：prepareToPlay をメインスレッドから外す案もあるが、実機で再現してからでよい。

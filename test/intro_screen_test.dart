import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/intro_screen.dart';
import 'package:flutter_application_1/login_page.dart';

class _PreparedPlayer extends Fake implements AudioPlayer {
  final prepared = Completer<void>();
  final playbackStarted = Completer<void>();
  int resumeCalls = 0;
  final seekPositions = <Duration>[];
  bool disposed = false;

  @override
  Future<void> setSource(Source source) => prepared.future;

  @override
  Future<void> seek(Duration position) async {
    seekPositions.add(position);
  }

  @override
  Future<void> resume() {
    resumeCalls++;
    return playbackStarted.future;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  testWidgets('Slow audio loading never delays the complete intro or login', (
    tester,
  ) async {
    final audio = _PreparedPlayer();
    await tester.pumpWidget(MaterialApp(home: IntroScreen(audioPlayer: audio)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 4300));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
    expect(audio.resumeCalls, 0);
    expect(audio.seekPositions, isEmpty);
    expect(audio.disposed, isTrue);
    audio.prepared.complete();
    await tester.pump();
    expect(audio.resumeCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ready sound starts at the bounce without holding animation', (
    tester,
  ) async {
    final audio = _PreparedPlayer();
    audio.prepared.complete();
    await tester.pumpWidget(MaterialApp(home: IntroScreen(audioPlayer: audio)));
    await tester.pump();
    final logo = find.image(const AssetImage('assets/images/logo.png'));
    final restingPosition = tester.getTopLeft(logo);
    await tester.pump(const Duration(milliseconds: 322));
    expect(audio.resumeCalls, 0);
    await tester.pump(const Duration(milliseconds: 2));
    expect(audio.resumeCalls, 1);
    expect(audio.seekPositions, [const Duration(seconds: 3)]);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getTopLeft(logo).dy, lessThan(restingPosition.dy));
    expect(audio.resumeCalls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(audio.disposed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Skip opens login immediately even while audio is loading', (
    tester,
  ) async {
    final audio = _PreparedPlayer();
    await tester.pumpWidget(MaterialApp(home: IntroScreen(audioPlayer: audio)));
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
    expect(audio.disposed, isTrue);
    audio.prepared.complete();
    await tester.pump();
    expect(audio.resumeCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Removing intro while audio is loading never starts playback', (
    tester,
  ) async {
    final audio = _PreparedPlayer();
    await tester.pumpWidget(MaterialApp(home: IntroScreen(audioPlayer: audio)));
    await tester.pumpWidget(const SizedBox.shrink());
    audio.prepared.complete();
    await tester.pump();
    expect(audio.disposed, isTrue);
    expect(audio.resumeCalls, 0);
    expect(audio.seekPositions, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Intro branding fits narrow screens with larger text until the full reveal',
    (tester) async {
      tester.view.physicalSize = const Size(280, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final audio = _PreparedPlayer();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: IntroScreen(audioPlayer: audio),
        ),
      );
      await tester.pump();
      for (final elapsed in [
        const Duration(milliseconds: 500),
        const Duration(milliseconds: 700),
        const Duration(milliseconds: 1000),
        const Duration(milliseconds: 1800),
      ]) {
        await tester.pump(elapsed);
        final rect = tester.getRect(
          find.image(const AssetImage('assets/images/logo.png')),
        );
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(280));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(360));
        expect(tester.takeException(), isNull);
      }
      expect(find.byType(IntroScreen), findsOneWidget);
      expect(
        tester
            .widget<ClipRect>(find.byKey(const ValueKey('lumear-word-mask')))
            .clipper,
        isA<LumearWordMask>().having((c) => c.progress, 'fully revealed', 1),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      audio.prepared.complete();
      await tester.pump();
    },
  );
}

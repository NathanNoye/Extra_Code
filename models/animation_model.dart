import 'package:flutter/material.dart';
import 'package:nurosene/core/enums/animation_type_enum.dart';
import 'package:nurosene/core/enums/breath_type_enum.dart';
import 'package:nurosene/core/enums/breathe_animation_orientation.dart';

// A model to represent an animation we receive from the Contentful Content team
// Part of the animation builder system that was built to integrate with Contentful's headless CMS
// On Contentful - I built it so the content authors could create an array of animations af various types. These animations were used to create neurological tests for our users
class AnimationModel {
  final String contentfulId;
  final String name;

  // Enum - what kind of animation should this be?
  // Possible types are:
  /*
    - Saccade
    - Pursuit
    - VOR
    - Breath
    - Text
    - Video
    - Gaze Stabilization
   */
  // The video type is in case we dont have an animation built yet so our users can still get the latest visual excercises and we can change them to be flutter animations later so it reduces data usage, loads faster, and so we can cache the animations in Hive
  final AnimationTypes type;
  final int iterations;

  // Enum - used to dictate if the animation should be linear or easeInOut
  final Curve animationCurve;

  // Enum - If this animation should be played in portrait or landscape
  final AnimationOrientation orientation;
  final int? pursuitMillisecondsToComplete;
  final int? saccadeHoldTime;
  final int? gazeStabilizationHoldTime;
  final int? vorHoldTimeMilliseconds;
  final int? textDisplayTime;
  final String? animatedTextText;
  final String? videoUrl;
  final Color? videoBackgroundColor;
  final List<Alignment>? positions;
  final List<BreathStep>? breathSteps;
  final bool? pursuitSaccadeCoordinatesEndAtStart;
  final bool? pursuitSuperSmooth;
  final String? audioUrl;
  String? cachedAudio;
  final String? animationImageUrl;
  final String? backgroundMediaUrl;
  final double? animationImageWidth;
  final double? animationImageHeight;
  final Color? breathingAnimationRingColor;

  AnimationModel({
    required this.contentfulId,
    required this.type,
    required this.iterations,
    required this.animationCurve,
    required this.orientation,
    required this.name,
    this.pursuitMillisecondsToComplete,
    this.saccadeHoldTime,
    this.gazeStabilizationHoldTime,
    this.vorHoldTimeMilliseconds,
    this.textDisplayTime,
    this.animatedTextText,
    this.videoUrl,
    this.videoBackgroundColor,
    this.positions,
    this.breathSteps,
    this.pursuitSaccadeCoordinatesEndAtStart,
    this.pursuitSuperSmooth,
    this.audioUrl,
    this.animationImageUrl,
    this.backgroundMediaUrl,
    this.animationImageWidth,
    this.animationImageHeight,
    this.breathingAnimationRingColor,
  });

  factory AnimationModel.fromJson(Map<String, dynamic> json) {
    return AnimationModel(
      contentfulId: json['id'],
      type: AnimationTypesExtension.fromString(json['type']),
      iterations: json['iteration'],
      name: json["name"] ?? "",
      pursuitMillisecondsToComplete: json['pursuitMillisecondsToComplete'],
      saccadeHoldTime: json['saccadeHoldTime'],
      gazeStabilizationHoldTime: json['gazeStabilizationHoldTime'],
      vorHoldTimeMilliseconds: json['vorHoldTimeMilliseconds'],
      animationCurve: getCurveType(json['animationCurve']),
      orientation:
          AnimationOrientationExtension.fromString(json['orientation']),
      textDisplayTime: json['textDisplayTime'],
      animatedTextText: json['animatedTextText'],
      videoUrl: json['videoUrl'],
      videoBackgroundColor:
          json['videoBackgroundColor'] == 'white' ? Colors.white : Colors.black,
      positions: json['pursuitSaccadePositionCollection'] != null
          ? getAlignmentType(json['pursuitSaccadePositionCollection'])
          : null,
      breathSteps: json['breathStepsCollection'] != null
          ? parseBreathSteps(json['breathStepsCollection'])
          : null,
      pursuitSaccadeCoordinatesEndAtStart:
          json['pursuitSaccadeCoordinatesEndAtStart'],
      pursuitSuperSmooth: json['pursuitSuperSmooth'],
      audioUrl: json['audio'],
      animationImageUrl: json['animationImage'],
      backgroundMediaUrl: json['backgroundMedia'],
      animationImageWidth: json['animationImageWidth'] != null
          ? (json['animationImageWidth'] as int).toDouble()
          : null,
      animationImageHeight: json['animationImageHeight'] != null
          ? (json['animationImageHeight'] as int).toDouble()
          : null,
    );
  }

  static Curve getCurveType(String value) {
    if (value == 'linear') {
      return Curves.linear;
    }

    if (value == 'easeInOut') {
      return Curves.easeInOut;
    }

    return Curves.linear;
  }

  static List<Alignment> getAlignmentType(List<dynamic> collection) {
    List<Alignment> positions = [];

    collection.forEach((currentPosition) {
      currentPosition as Map<String, dynamic>;

      Alignment position = Alignment(
        currentPosition['xPosition'].toDouble(),
        currentPosition['yPosition'].toDouble(),
      );

      positions.add(position);
    });

    return positions;
  }

  static List<BreathStep> parseBreathSteps(List<dynamic> steps) {
    List<BreathStep> entries = [];

    for (final Map<String, dynamic> step in steps) {
      entries.add(BreathStep.fromJson(step));
    }

    return entries;
  }
}

class BreathStep {
  final String id;
  final String title;
  final BreathType type;
  final int duration;
  final String text;
  final String? audioUrl;
  String? cachedAudioUrl;
  final bool? isLongHold;
  final Color? ringColor;
  final Color? backgroundColor;

  BreathStep({
    required this.id,
    required this.type,
    required this.duration,
    required this.text,
    required this.title,
    this.audioUrl,
    this.isLongHold,
    this.ringColor,
    this.backgroundColor,
  });

  factory BreathStep.fromJson(Map<String, dynamic> json) {
    return BreathStep(
      id: json["id"] ?? "",
      title: json["title"] ?? "",
      type: BreathTypeExtension.fromString(json['type']),
      duration: json['duration'],
      text: json['text'],
      audioUrl: json['audio'],
      isLongHold: json['isLongHold'],
      ringColor: json['ringColor'] != null
          ? Color(int.parse('0xff${json['ringColor']}'))
          : null,
      backgroundColor: json['backgroundColor'] != null
          ? Color(int.parse('0xff${json['backgroundColor']}'))
          : null,
    );
  }
}

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'constants.dart';
import 'label_painter.dart';
import 'overlay_painter.dart';
import 'step.dart';

const double sideGap = 5;
const Color debugBorderColor = Color(0xFFFF0000);

class OnboardingStepper extends StatefulWidget {
  OnboardingStepper({
    Key? key,
    this.initialIndex = 0,
    required this.steps,
    this.duration = const Duration(milliseconds: 350),
    this.pulseDuration = const Duration(milliseconds: 1000),
    this.onChanged,
    this.onEnd,
    this.autoSizeTexts = false,
    this.stepIndexes = const <int>[],
    this.debugBoundaries = false,
    required this.setupIndex,
    required this.constraints,
  })  : assert(() {
          if (stepIndexes.isNotEmpty && !stepIndexes.contains(initialIndex)) {
            final List<DiagnosticsNode> information = <DiagnosticsNode>[
              ErrorSummary('stepIndexes should contain initialIndex'),
            ];

            throw FlutterError.fromParts(information);
          }
          return true;
        }()),
        super(key: key);

  /// is reqired
  final List<OnboardingStep> steps;

  /// By default, vali is 0
  final int initialIndex;

  /// By default stepIndexes os an empty array
  final List<int> stepIndexes;

  ///  `onChanged` is called everytime when the previous step has faded out,
  ///
  /// before the next step is shown with a value of the step index on which the user was
  final ValueChanged<int>? onChanged;

  /// `onEnd` is called when there are no more steps to transition to
  final ValueChanged<int>? onEnd;

  final ValueChanged<int> setupIndex;

  /// By default, the value is `Duration(milliseconds: 350)`
  final Duration duration;

  /// By default, the value is `Duration(milliseconds: 1000)`
  final Duration pulseDuration;

  /// By default is `false`, turns on to usage of `AutoSizeText` widget and ignore `maxLines`
  final bool autoSizeTexts;

  /// By default the value is false
  final bool debugBoundaries;

  final BoxConstraints constraints;

  @override
  _OnboardingStepperState createState() => _OnboardingStepperState();
}

class _OnboardingStepperState extends State<OnboardingStepper>
    with TickerProviderStateMixin {
  late int stepperIndex;
  late ColorTween overlayColorTween;
  late AnimationController overlayController;
  late AnimationController pulseController;
  late Animation<double> overlayAnimation;
  late Animation<double> pulseAnimationInner;
  late Animation<double> pulseAnimationOuter;
  late List<int> _stepIndexes;
  late RectTween holeTween;
  Offset? holeOffset;
  Rect? widgetRect;
  final GlobalKey overlayKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // stepperIndex = widget.initialIndex;
    _stepIndexes = List<int>.from(widget.stepIndexes);
    overlayController = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..addListener(() {
        setState(() {});
      });

    pulseController = AnimationController(
      vsync: this,
      duration: widget.pulseDuration,
    )..addListener(() {
        setState(() {});
      });

    overlayAnimation = CurvedAnimation(
      curve: Curves.ease,
      parent: overlayController,
    );

    pulseAnimationInner = CurvedAnimation(
      curve: Curves.ease,
      parent: pulseController,
    );

    pulseAnimationOuter = CurvedAnimation(
      curve: const Interval(
        0.0,
        0.8,
        curve: Curves.ease,
      ),
      parent: pulseController,
    );

    holeTween = RectTween(
      begin: Rect.zero,
      end: Rect.zero,
    );

    overlayColorTween = ColorTween(
      begin: null,
      end: null,
    );

    startStepper(fromIndex: widget.initialIndex);
    calcWidgetRect(widget.steps[stepperIndex]);
  }

  Future<void> startStepper({int fromIndex = 0}) async {
    assert(() {
      if (widget.stepIndexes.isNotEmpty &&
          !widget.stepIndexes.contains(widget.initialIndex)) {
        final List<DiagnosticsNode> information = <DiagnosticsNode>[
          ErrorSummary('stepIndexes should contain initialIndex'),
        ];

        throw FlutterError.fromParts(information);
      }
      return true;
    }());
    assert(() {
      if (fromIndex >= widget.steps.length && fromIndex < 0) {
        final List<DiagnosticsNode> information = <DiagnosticsNode>[
          ErrorSummary(
              'fromIndex cannot be bigger then the number of steps or smaller than zero.'),
        ];

        throw FlutterError.fromParts(information);
      }
      return true;
    }());

    OnboardingStep step;

    if (widget.stepIndexes.isEmpty) {
      stepperIndex = fromIndex;
      step = widget.steps[stepperIndex];
      if (stepperIndex > 0) {
        await Future<void>.delayed(step.delay);
      }
    } else {
      stepperIndex = widget.initialIndex;
      _stepIndexes.removeAt(0);
      step = widget.steps[stepperIndex];
    }
    widget.setupIndex(stepperIndex);

    setTweensAndAnimate(step);
    step.focusNode.requestFocus();
  }

  Future<void> _nextStep() async {
    assert(() {
      if (widget.stepIndexes.isNotEmpty &&
          !widget.stepIndexes.contains(widget.initialIndex)) {
        final List<DiagnosticsNode> information = <DiagnosticsNode>[
          ErrorSummary('stepIndexes should contain initialIndex'),
        ];

        throw FlutterError.fromParts(information);
      }
      return true;
    }());

    if (widget.stepIndexes.isEmpty) {
      await overlayController.reverse();
      widget.onChanged?.call(stepperIndex);
      // await Future<void>.delayed(Duration(milliseconds: 1000));
      if (stepperIndex < widget.steps.length - 1) {
        setState(() {
          stepperIndex++;
        });
      } else {
        widget.onEnd?.call(stepperIndex);
        return;
      }

      final OnboardingStep step = widget.steps[stepperIndex];
      if (stepperIndex > 0) {
        await Future<void>.delayed(step.delay);
      }
      if (stepperIndex < widget.steps.length && stepperIndex >= 0) {
        setTweensAndAnimate(step);
        step.focusNode.requestFocus();
      }
    } else {
      await overlayController.reverse();

      widget.onChanged?.call(stepperIndex);

      if (_stepIndexes.isEmpty) {
        widget.onEnd?.call(stepperIndex);
        return;
      }

      if (_stepIndexes.isNotEmpty) {
        setState(() {
          stepperIndex = _stepIndexes.first;
        });
        _stepIndexes.removeAt(0);
      }

      final OnboardingStep step = widget.steps[stepperIndex];
      await Future<void>.delayed(step.delay);

      if (widget.stepIndexes.indexWhere((int el) => el == stepperIndex) != -1) {
        setTweensAndAnimate(step);
        step.focusNode.requestFocus();
      }
    }
    setState(() {
      calcWidgetRect(widget.steps[stepperIndex]);
    });
  }

  @override
  void didUpdateWidget(OnboardingStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.constraints != widget.constraints) {
      setState(() {
        calcWidgetRect(widget.steps[stepperIndex]);
      });
    }
  }

  @override
  void dispose() {
    overlayController.dispose();
    pulseController.dispose();
    super.dispose();
  }

  void calcWidgetRect(OnboardingStep step) {
    final RenderBox? box =
        step.focusNode.context?.findRenderObject() as RenderBox?;

    holeOffset = box?.localToGlobal(Offset.zero);
    widgetRect = box != null ? holeOffset! & box.size : null;
    holeTween = widgetRect != null
        ? RectTween(
            begin: Rect.zero.shift(widgetRect!.center),
            end: step.margin.inflateRect(widgetRect!),
          )
        : RectTween(
            begin: Rect.zero,
            end: Rect.zero,
          );
  }

  void overlayStatusCallback(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      pulseController
        ..forward(from: 0.0)
        ..repeat(reverse: true);
    }

    if (status == AnimationStatus.reverse) {
      pulseController.reset();
    }
  }

  void setTweensAndAnimate(OnboardingStep step) async {
    overlayColorTween = ColorTween(
      begin: step.overlayColor.withOpacity(overlayAnimation.value),
      end: step.overlayColor,
    );

    overlayController.removeStatusListener(overlayStatusCallback);

    if (step.showPulseAnimation) {
      overlayController.addStatusListener(overlayStatusCallback);
    }

    await overlayController.forward(from: 0.0);
  }

  double _getHorizontalPosition(
    OnboardingStep step,
    Size size,
    double boxWidth,
  ) {
    if (widgetRect != null) {
      if (widgetRect!.center.dx > size.width / 2) {
        return (widgetRect!.center.dx - boxWidth / 2)
            .clamp(sideGap, size.width - boxWidth - sideGap);
      } else if (widgetRect!.center.dx == size.width / 2) {
        return (widgetRect!.center.dx - boxWidth / 2)
            .clamp(sideGap, size.width - boxWidth - sideGap);
      } else {
        return (widgetRect!.center.dx - boxWidth / 2)
            .clamp(sideGap, size.width - boxWidth - sideGap);
      }
    } else {
      return size.width / 2 - boxWidth / 2;
    }
  }

  double _getVerticalPosition(
    OnboardingStep step,
    Size size,
    double boxHeight,
  ) {
    final double spacer = (step.hasArrow ? kArrowHeight + kSpace : kSpace);

    if (widgetRect != null) {
      final Rect holeRect = step.margin.inflateRect(widgetRect!);

      if (widgetRect!.center.dy > size.height / 2) {
        return (holeRect.top - boxHeight - spacer)
            .clamp(0, size.height - boxHeight);
      } else {
        return (holeRect.bottom + spacer).clamp(0, size.height - boxHeight);
      }
    } else {
      return size.height / 2 - boxHeight / 2;
    }
  }

  void _close() {
    widget.onEnd?.call(stepperIndex);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MediaQueryData media = MediaQuery.of(context);
    final Size mediaSize = media.size;
    final OnboardingStep step = widget.steps[stepperIndex];

    final TextTheme textTheme = theme.textTheme;
    final TextStyle localTitleTextStyle =
        textTheme.headline5!.copyWith(color: step.titleTextColor);
    final TextStyle localBodyTextStyle =
        textTheme.bodyText1!.copyWith(color: step.bodyTextColor);

    final TextStyle stepTitleTextStyle = textTheme.headline5!.copyWith(
      color: step.titleTextStyle?.color ?? step.titleTextColor,
    );

    final TextStyle stepBodyTextStyle = textTheme.bodyText1!.copyWith(
      color: step.bodyTextStyle?.color ?? step.bodyTextColor,
    );

    final TextStyle activeTitleStyle = textTheme.headline5!.merge(
        step.titleTextStyle != null ? stepTitleTextStyle : localTitleTextStyle);

    final TextStyle activeBodyStyle = textTheme.bodyText1!.merge(
        step.bodyTextStyle != null ? stepBodyTextStyle : localBodyTextStyle);

    Rect holeRect = Rect.fromCenter(
      center: Offset(mediaSize.shortestSide / 2, mediaSize.longestSide / 2),
      width: 0,
      height: 0,
    );

    if (widgetRect != null) {
      holeRect = step.margin.inflateRect(widgetRect!);
    }

    final bool isTop = holeRect.center.dy > mediaSize.height / 2;

    final double boxWidth = step.fullscreen
        ? mediaSize.width - 2 * sideGap
        : widgetRect != null
            ? mediaSize.width * kLabelBoxWidthRatio
            : mediaSize.width * kOverlayRatio;

    double boxHeight = 0;
    if (step.fullscreen) {
      if (holeRect.height > 0) {
        if (isTop) {
          boxHeight = holeRect.top -
              sideGap -
              (step.hasArrow ? kArrowHeight + sideGap : sideGap) -
              media.padding.top;
        } else {
          boxHeight = mediaSize.height -
              holeRect.bottom -
              sideGap -
              (step.hasArrow ? kArrowHeight + sideGap : sideGap) -
              media.padding.top;
        }
      } else {
        boxHeight = mediaSize.height -
            sideGap -
            (step.hasArrow ? kArrowHeight + sideGap : sideGap) -
            2 * media.padding.top;
      }
    } else {
      if (widgetRect != null) {
        boxHeight = mediaSize.width * kLabelBoxWidthRatio -
            kSpace -
            (step.hasArrow ? kArrowHeight + sideGap : sideGap);
      } else {
        boxHeight = mediaSize.height * kLabelBoxWidthRatio -
            kSpace -
            (step.hasArrow ? kArrowHeight + sideGap : sideGap);
      }
    }

    final double leftPos = _getHorizontalPosition(step, mediaSize, boxWidth);
    final double topPos = _getVerticalPosition(step, mediaSize, boxHeight);
    final Rect? holeAnimatedValue = holeTween.evaluate(overlayAnimation);
    final Color? colorAnimatedValue =
        overlayColorTween.evaluate(overlayAnimation);

    return GestureDetector(
      behavior: step.overlayBehavior == OverlayBehavior.deferToChild
          ? HitTestBehavior.deferToChild
          : HitTestBehavior.opaque,
      onTapDown: (TapDownDetails details) {
        final BoxHitTestResult result = BoxHitTestResult();
        final RenderBox overlayBox =
            overlayKey.currentContext?.findRenderObject() as RenderBox;

        Offset localOverlay = overlayBox.globalToLocal(details.globalPosition);

        if (step.onTapCallback != null) {
          final TapArea area =
              overlayBox.hitTest(result, position: localOverlay)
                  ? TapArea.overlay
                  : TapArea.hole;
          step.onTapCallback?.call(area, _nextStep, _close);
          return;
        }

        if ((overlayBox.hitTest(result, position: localOverlay) ||
                step.overlayBehavior != OverlayBehavior.deferToChild) &&
            step.stepBuilder == null &&
            step.onTapCallback == null) {
          _nextStep();
        }
      },
      child: Stack(
        key: step.key,
        clipBehavior: Clip.antiAlias,
        children: <Widget>[
          AnimatedOverlay(
            overlayKey: overlayKey,
            size: mediaSize,
            step: step,
            holeAnimatedValue: holeAnimatedValue,
            overlayAnimation: overlayAnimation.value,
            pulseAnimationInner: pulseAnimationInner.value,
            pulseAnimationOuter: pulseAnimationOuter.value,
            colorAnimatedValue: colorAnimatedValue,
          ),
          Positioned(
            left: leftPos,
            top: topPos,
            child: AnimatedLabel(
              overlayAnimation: overlayAnimation,
              debugBoundaries: widget.debugBoundaries,
              size: Size(boxWidth, boxHeight),
              isTop: isTop,
              step: step,
              holeAnimatedValue:
                  holeAnimatedValue?.shift(Offset(-leftPos, -topPos)) ??
                      Rect.zero,
              leftPos: leftPos,
              topPos: topPos,
              autoSizeTexts: widget.autoSizeTexts,
              activeTitleStyle: activeTitleStyle,
              activeBodyStyle: activeBodyStyle,
              next: _nextStep,
              close: _close,
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedLabel extends StatelessWidget {
  const AnimatedLabel({
    Key? key,
    required this.overlayAnimation,
    required this.debugBoundaries,
    required this.size,
    required this.isTop,
    required this.step,
    required this.holeAnimatedValue,
    required this.leftPos,
    required this.topPos,
    required this.autoSizeTexts,
    required this.activeTitleStyle,
    required this.activeBodyStyle,
    required this.close,
    required this.next,
  }) : super(key: key);

  final Animation<double> overlayAnimation;
  final Size size;
  final bool isTop;
  final OnboardingStep step;
  final Rect holeAnimatedValue;
  final double leftPos;
  final double topPos;
  final bool autoSizeTexts;
  final bool debugBoundaries;
  final TextStyle activeTitleStyle;
  final TextStyle activeBodyStyle;
  final VoidCallback close;
  final VoidCallback next;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: overlayAnimation,
      child: Container(
        decoration: debugBoundaries
            ? BoxDecoration(
                border: Border.all(color: debugBorderColor),
              )
            : null,
        width: size.width,
        height: size.height,
        child: Stack(
          clipBehavior: Clip.antiAlias,
          alignment: isTop ? Alignment.bottomCenter : Alignment.topCenter,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                painter: LabelPainter(
                  opacity: 1,
                  hasLabelBox: step.hasLabelBox,
                  labelBoxPadding: step.labelBoxPadding,
                  labelBoxDecoration: step.labelBoxDecoration,
                  hasArrow: step.hasArrow,
                  arrowPosition: step.arrowPosition,
                  hole: holeAnimatedValue,
                  isTop: isTop,
                ),
                child: SizedBox(
                  width: size.width,
                  child: Padding(
                    padding: step.labelBoxPadding,
                    child: step.stepBuilder != null
                        ? step.stepBuilder!(
                            context,
                            OnboardingStepRenderInfo(
                              titleText: step.titleText,
                              titleStyle: activeTitleStyle,
                              bodyText: step.bodyText,
                              bodyStyle: activeBodyStyle,
                              size: size,
                              nextStep: next,
                              close: close,
                            ),
                          )
                        : autoSizeTexts
                            ? AutoSizeText.rich(
                                TextSpan(
                                  text: step.titleText,
                                  style: activeTitleStyle,
                                  children: <InlineSpan>[
                                    const TextSpan(text: '\n'),
                                    TextSpan(
                                      text: step.bodyText,
                                      style: activeBodyStyle,
                                    )
                                  ],
                                ),
                                textDirection: Directionality.of(context),
                                textAlign: step.textAlign,
                                minFontSize: 12,
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisAlignment: isTop
                                    ? MainAxisAlignment.end
                                    : MainAxisAlignment.start,
                                children: [
                                  Text(
                                    step.titleText,
                                    style: activeTitleStyle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: step.textAlign,
                                    textDirection: Directionality.of(context),
                                  ),
                                  Text(
                                    step.bodyText,
                                    style: activeBodyStyle,
                                    maxLines: 5,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: step.textAlign,
                                    textDirection: Directionality.of(context),
                                  )
                                ],
                              ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class AnimatedOverlay extends StatelessWidget {
  const AnimatedOverlay({
    Key? key,
    required this.overlayKey,
    required this.size,
    required this.step,
    this.holeAnimatedValue,
    this.colorAnimatedValue,
    required this.overlayAnimation,
    required this.pulseAnimationInner,
    required this.pulseAnimationOuter,
  }) : super(key: key);

  final GlobalKey<State<StatefulWidget>> overlayKey;
  final Size size;
  final OnboardingStep step;
  final Rect? holeAnimatedValue;
  final double overlayAnimation;
  final double pulseAnimationInner;
  final double pulseAnimationOuter;
  final Color? colorAnimatedValue;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        key: overlayKey,
        size: Size(
          size.width,
          size.height,
        ),
        painter: OverlayPainter(
          fullscreen: step.fullscreen,
          shape: step.shape,
          overlayShape: step.overlayShape,
          center:
              step.focusNode.context == null ? size.center(Offset.zero) : null,
          hole: holeAnimatedValue ?? Rect.zero,
          overlayAnimation: overlayAnimation,
          pulseInnerColor: step.pulseInnerColor,
          pulseOuterColor: step.pulseOuterColor,
          pulseAnimationInner: pulseAnimationInner,
          pulseAnimationOuter: pulseAnimationOuter,
          overlayColor: colorAnimatedValue ?? const Color(0xaa000000),
          showPulseAnimation: step.showPulseAnimation,
        ),
      ),
    );
  }
}

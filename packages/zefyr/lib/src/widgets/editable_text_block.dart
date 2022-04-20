import 'package:flutter/material.dart';
import 'package:notus/notus.dart';
import 'package:zefyr/util.dart';

import '../rendering/editable_text_block.dart';
import 'controller.dart';
import 'cursor.dart';
import 'editable_text_line.dart';
import 'editor.dart';
import 'link.dart';
import 'text_line.dart';
import 'theme.dart';

class EditableTextBlock extends StatelessWidget {
  final BlockNode node;
  final ZefyrController controller;
  final bool readOnly;
  final VerticalSpacing spacing;
  final CursorController cursorController;
  final TextSelection selection;
  final Color selectionColor;
  final bool enableInteractiveSelection;
  final bool hasFocus;
  final ZefyrEmbedBuilder embedBuilder;
  final LinkActionPicker linkActionPicker;
  final ValueChanged<String?>? onLaunchUrl;
  final EdgeInsets? contentPadding;

  const EditableTextBlock({
    Key? key,
    required this.node,
    required this.controller,
    required this.readOnly,
    required this.spacing,
    required this.cursorController,
    required this.selection,
    required this.selectionColor,
    required this.enableInteractiveSelection,
    required this.hasFocus,
    required this.embedBuilder,
    required this.linkActionPicker,
    this.onLaunchUrl,
    this.contentPadding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMediaQuery(context));

    final theme = ZefyrTheme.of(context)!;
    return _EditableBlock(
      node: node,
      padding: spacing,
      contentPadding: contentPadding,
      decoration: _getDecorationForBlock(node, theme) ?? const BoxDecoration(),
      children: _buildChildren(context),
    );
  }

  List<Widget> _buildChildren(BuildContext context) {
    final theme = ZefyrTheme.of(context)!;
    final count = node.children.length;
    final children = <Widget>[];
    var index = 0;
    for (final line in node.children) {
      index++;
      final nodeTextDirection = getDirectionOfNode(line as LineNode);
      final listDepth = _getListDepth(line);
      final listIndent = listDepth.toDouble() * _getIndentWidth();
      children.add(Directionality(
        textDirection: nodeTextDirection,
        child: EditableTextLine(
          node: line,
          spacing: _getSpacingForLine(line, index, count, theme),
          leading: _buildLeading(
            context,
            line,
            index,
            count,
            listIndent,
            listDepth,
          ),
          indentWidth: _getIndentWidth() + listIndent,
          devicePixelRatio: MediaQuery.of(context).devicePixelRatio,
          body: TextLine(
            node: line,
            readOnly: readOnly,
            controller: controller,
            embedBuilder: embedBuilder,
            linkActionPicker: linkActionPicker,
            onLaunchUrl: onLaunchUrl,
          ),
          cursorController: cursorController,
          selection: selection,
          selectionColor: selectionColor,
          enableInteractiveSelection: enableInteractiveSelection,
          hasFocus: hasFocus,
        ),
      ));
    }
    return children.toList(growable: false);
  }

  Widget? _buildLeading(BuildContext context, LineNode node, int index,
      int count, double listIndent, int listDepth) {
    final theme = ZefyrTheme.of(context)!;
    final block = node.style.get(NotusAttribute.block);
    if (block == NotusAttribute.block.numberList) {
      return _NumberPoint(
        index: index,
        count: count,
        depth: listDepth,
        style: theme.paragraph.style,
        width: 32.0,
        padding: listIndent,
      );
    } else if (block == NotusAttribute.block.bulletList) {
      return _BulletPoint(
        style: theme.paragraph.style.copyWith(fontWeight: FontWeight.bold),
        width: 32,
        padding: 2.0,
      );
    } else if (block == NotusAttribute.block.code) {
      return _NumberPoint(
        index: index,
        count: count,
        depth: 0,
        style: theme.code.style
            .copyWith(color: theme.code.style.color?.withOpacity(0.4)),
        width: 32.0,
        padding: 16.0,
        withDot: false,
      );
    } else if (block == NotusAttribute.block.checkList) {
      return _CheckboxPoint(
        size: 14,
        value: node.style.containsSame(NotusAttribute.checked),
        enabled: !readOnly,
        onChanged: (checked) => _toggle(node, checked),
      );
    } else {
      return null;
    }
  }

  double _getIndentWidth() {
    final block = node.style.get(NotusAttribute.block);
    if (block == NotusAttribute.block.quote) {
      return 16.0;
    } else if (block == NotusAttribute.block.code) {
      return 32.0;
    } else {
      return 28.0;
    }
  }

  int _getListDepth(LineNode line) {
    final block = node.style.get(NotusAttribute.block);
    if (block == NotusAttribute.block.numberList ||
        block == NotusAttribute.block.bulletList ||
        block == NotusAttribute.block.checkList) {
      return (line.style.get(NotusAttribute.indent(0))?.value as int?) ?? 0;
      ;
    }

    return 0;
  }

  VerticalSpacing _getSpacingForLine(
      LineNode node, int index, int count, ZefyrThemeData theme) {
    final heading = node.style.get(NotusAttribute.heading);

    double? top;
    double? bottom;

    if (heading == NotusAttribute.heading.level1) {
      top = theme.heading1.spacing.top;
      bottom = theme.heading1.spacing.bottom;
    } else if (heading == NotusAttribute.heading.level2) {
      top = theme.heading2.spacing.top;
      bottom = theme.heading2.spacing.bottom;
    } else if (heading == NotusAttribute.heading.level3) {
      top = theme.heading3.spacing.top;
      bottom = theme.heading3.spacing.bottom;
    } else {
      final block = this.node.style.get(NotusAttribute.block);
      VerticalSpacing? lineSpacing;
      if (block == NotusAttribute.block.quote) {
        lineSpacing = theme.quote.lineSpacing;
      } else if (block == NotusAttribute.block.numberList ||
          block == NotusAttribute.block.bulletList ||
          block == NotusAttribute.block.checkList) {
        lineSpacing = theme.lists.lineSpacing;
      } else if (block == NotusAttribute.block.code ||
          block == NotusAttribute.block.code) {
        lineSpacing = theme.lists.lineSpacing;
      }
      top = lineSpacing?.top;
      bottom = lineSpacing?.bottom;
    }

    // If this line is the top one in this block we ignore its top spacing
    // because the block itself already has it. Similarly with the last line
    // and its bottom spacing.
    if (index == 1) {
      top = 0.0;
    }

    if (index == count) {
      bottom = 0.0;
    }

    return VerticalSpacing(top: top ?? 0, bottom: bottom ?? 0);
  }

  BoxDecoration? _getDecorationForBlock(BlockNode node, ZefyrThemeData theme) {
    final style = node.style.get(NotusAttribute.block);
    if (style == NotusAttribute.block.quote) {
      return theme.quote.decoration;
    } else if (style == NotusAttribute.block.code) {
      return theme.code.decoration;
    }
    return null;
  }

  void _toggle(LineNode node, bool checked) {
    final attr =
        checked ? NotusAttribute.checked : NotusAttribute.checked.unset;
    controller.formatText(node.documentOffset, 0, attr);
  }
}

class _EditableBlock extends MultiChildRenderObjectWidget {
  final BlockNode node;
  final VerticalSpacing padding;
  final Decoration decoration;
  final EdgeInsets? contentPadding;

  _EditableBlock({
    Key? key,
    required this.node,
    required this.decoration,
    required List<Widget> children,
    this.contentPadding,
    this.padding = const VerticalSpacing(),
  }) : super(key: key, children: children);

  EdgeInsets get _padding =>
      EdgeInsets.only(top: padding.top, bottom: padding.bottom);

  EdgeInsets get _contentPadding => contentPadding ?? EdgeInsets.zero;

  @override
  RenderEditableTextBlock createRenderObject(BuildContext context) {
    return RenderEditableTextBlock(
      node: node,
      textDirection: Directionality.of(context),
      padding: _padding,
      decoration: decoration,
      contentPadding: _contentPadding,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderEditableTextBlock renderObject) {
    renderObject.node = node;
    renderObject.textDirection = Directionality.of(context);
    renderObject.padding = _padding;
    renderObject.decoration = decoration;
    renderObject.contentPadding = _contentPadding;
  }
}

class _NumberPoint extends StatelessWidget {
  final int index;
  final int count;
  final int depth;
  final double width;
  final bool withDot;
  final double padding;
  final TextStyle style;

  const _NumberPoint({
    Key? key,
    required this.index,
    required this.count,
    required this.depth,
    required this.width,
    required this.style,
    this.withDot = true,
    this.padding = 0.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final text = _getText();
    return Container(
      alignment: AlignmentDirectional.topStart,
      width: width,
      padding: EdgeInsetsDirectional.only(start: padding),
      child: Text(withDot ? '$text.' : '$text', style: style),
    );
  }

  String _getText() {
    switch (depth) {
      case 0:
        return '$index';
      case 1:
        // Use modulo to cycle around the alphabets,
        // avoiding index out of bounds error.
        final indexOfValue = (index - 1) % (_alphabets.length - 1);
        return _alphabets[indexOfValue];
      case 2:
        // Use modulo to cycle around the alphabets,
        // avoiding index out of bounds error.
        final indexOfValue = (index - 1) % (_romanNumerals.length - 1);
        return _romanNumerals[indexOfValue];
      default:
        return '$index';
    }
  }
}

// Constants for numbered list

const _alphabets = [
  "a",
  "b",
  "c",
  "d",
  "e",
  "f",
  "g",
  "h",
  "i",
  "j",
  "k",
  "l",
  "m",
  "n",
  "o",
  "p",
  "q",
  "r",
  "s",
  "t",
  "u",
  "v",
  "w",
  "x",
  "y",
  "z",
  "aa",
  "ab",
  "ac",
  "ad",
  "ae",
  "af",
  "ag",
  "ah",
  "ai",
  "aj",
  "ak",
  "al",
  "am",
  "an",
  "ao",
  "ap",
  "aq",
  "ar",
  "as",
  "at",
  "au",
  "av",
  "aw",
  "ax",
  "ay",
  "az",
];

const _romanNumerals = [
  "i",
  "ii",
  "iii",
  "iv",
  "v",
  "vi",
  "vii",
  "viii",
  "ix",
  "x",
  "xi",
  "xii",
  "xiii",
  "xiv",
  "xv",
  "xvi",
  "xvii",
  "xviii",
  "xix",
  "xx",
  "xxi",
  "xxii",
  "xxiii",
  "xxiv",
  "xxv",
  "xxvi",
  "xxvii",
  "xxviii",
  "xxix",
  "xxx"
];

class _BulletPoint extends StatelessWidget {
  final double width;
  final TextStyle style;
  final double padding;

  const _BulletPoint({
    Key? key,
    required this.width,
    required this.style,
    this.padding = 0.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: AlignmentDirectional.topStart,
      width: width,
      padding: EdgeInsetsDirectional.only(start: padding),
      child: Text('•', style: style),
    );
  }
}

class _CheckboxPoint extends StatefulWidget {
  final double size;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  const _CheckboxPoint({
    Key? key,
    required this.size,
    required this.value,
    required this.enabled,
    required this.onChanged,
  }) : super(key: key);

  @override
  _CheckboxPointState createState() => _CheckboxPointState();
}

class _CheckboxPointState extends State<_CheckboxPoint> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var fillColor = widget.value
        ? (widget.enabled
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface.withOpacity(0.5))
        : theme.colorScheme.surface;
    var borderColor = widget.value
        ? (widget.enabled
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface.withOpacity(0))
        : (widget.enabled
            ? theme.colorScheme.onSurface.withOpacity(0.5)
            : theme.colorScheme.onSurface.withOpacity(0.3));
    return Center(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Material(
          elevation: 0,
          color: fillColor,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: 1,
              color: borderColor,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
          child: InkWell(
            onTap:
                widget.enabled ? () => widget.onChanged(!widget.value) : null,
            child: widget.value
                ? Icon(Icons.check,
                    size: widget.size, color: theme.colorScheme.onPrimary)
                : null,
          ),
        ),
      ),
    );
  }
}

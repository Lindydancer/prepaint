# prepaint - Highlight C-style preprocessor directives

*Author:* Anders Lindgren<br>
*Version:* 0.0.0<br>


 *Prepaint* is an Emacs package that highlight C-style preprocessor
 statements. The main feature is support for macros that span
 multiple lines.

 Prepaint is implemented as two minor modes: `prepaint-mode` and
 `global-prepaint-mode`.  The former can be applied to individual buffers
 and the latter to all buffers.

 Activate this package by Customize, or by placing the following line
 into the appropriate init file:

        (global-prepaint-mode 1)

 This package use Fone Lock mode, so `font-lock-mode` or
 `global-font-lock-mode` must be enabled.

## Example

 Below is a screenshot of a sample C file, demonstrating the effect
 of this package:

 ![See doc/demo.png for screenshot of Prepaint mode](doc/demo.png)



---
Converted from `prepaint.el` by *el2markup*.
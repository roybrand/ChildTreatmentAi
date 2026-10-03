# Tutor lessons

Status: the prototype lesson below is built in its plain form, set by the Tutor in each child's own world; beauty is one such world, not the only one. The two styles, the read-aloud, and the other lessons are design. This file holds the first learning path and the first prototype lesson for the Tutor. The teaching method is defined in [AGENTS.md](AGENTS.md).

## First learning path: mathematics foundations

Four topics, in the order they build on each other. The first interest worlds are beauty, shopping, and an underwater cartoon world.

| Order | Topic | Interest world | The real link | Game template |
| --- | --- | --- | --- | --- |
| 1 | Fractions | Beauty: mixing nail polish shades and hair colour | A shade is a fraction of each colour. To make more of the same shade you need the same fraction | Mixer, slicer |
| 2 | Percentages | Shopping: discounts and deals at the mall | A price tag that says 30% off is a percentage problem people solve every day | Hundred bar, price tag |
| 3 | Equations | Shopping: a budget with an unknown price | "I had ₪200, bought 3 of the same polish, and have ₪80 left. What did one cost?" is an equation | Balance |
| 4 | Motion problems | Underwater world: two characters travelling to the same place | Speed, time, and distance, shown as movement the child controls | Track with two movers |

The link is strongest for the first three. For motion problems the beauty and shopping worlds offer no honest link, so the lesson uses the underwater world, where things really do move.

Fractions come first because percentages and equations both depend on them.

**On named characters.** The app cannot use characters or settings owned by others, such as those from television cartoons. The underwater world is an original one with the same playful feel.

## Two styles, chosen by the young person

Every lesson is available in two styles. The mathematics, the steps, and the game template are identical in both.

| | Studio | Cartoon |
| --- | --- | --- |
| Feel | Realistic and a little grown-up | Playful and silly |
| Look | Clean, like a beauty or shopping app | Bright, exaggerated, animated characters |
| Tutor's voice | A colleague: "A client wants a bigger bottle of your shade" | Jokes around, funny names, a goofy client who reacts |
| Sound | Minimal | Lively |

The young person picks a style the first time they open a lesson and can switch at any time from the lesson screen. The choice is kept in the "about me" part of their profile. Nobody chooses for them, and the app does not guess from their age.

How it is built: a style is a skin laid over the game template, made of a visual theme, a sound set, and a voice setting for the Tutor. The template and its logic are built once. The Tutor's voice costs almost nothing to vary. The visual theme is the real cost, so each new interest world needs its artwork made twice.

## Prototype lesson: Mix your shade

The lesson below is written in the studio style. In the cartoon style the same steps run with a comic client, silly shade names, and exaggerated mixing animation.

**Topic.** Fractions as parts of a whole, and equal fractions.

**World.** Beauty.

**Template.** Mixer: a bottle divided into equal slots, two colours to pour, and a live swatch showing the resulting shade.

**Length.** About ten minutes. It can stop after any step and resume later.

**Tone.** In either style the child is a nail artist creating a signature shade, not a pupil doing an exercise.

### 1. A real problem

"You've created your own shade for your nail studio. Your small bottle has 4 slots: 3 pink and 1 white. A client loves it and wants a big bottle, which has 8 slots. It has to be exactly the same shade. How much pink goes in?"

### 2. Play

The child taps to pour pink and white into the 8-slot bottle. The swatch changes colour with every tap, next to the target swatch from the small bottle. Nothing is marked wrong. A swatch that is too dark or too pale is simply visible.

### 3. Discover

At 6 pink and 2 white the two swatches match. The Tutor asks what the child notices about 3 and 4 compared with 6 and 8. The child sees it: both numbers doubled, and the shade stayed the same.

If the child does not see it, the Tutor offers the 12-slot bottle and asks them to match again, then lays the three bottles side by side.

### 4. Name it

"What you just did has a name. 3 out of 4 equal parts is written ¾. That is a fraction. And you found that ¾ and 6⁄8 are the same amount: equal fractions."

"Why people needed this: anyone who mixes something, whether paint, hair colour, a recipe, or medicine, has to be able to make the same thing again in a different size. A fraction is how you write down 'how much of the whole' so it works for any size."

### 5. Practise

Three more orders in the same studio:

- A 12-slot bottle of the same shade
- A new shade that is half pink, in a 4-slot and then a 10-slot bottle
- A client brings a 16-slot bottle with 12 pink. Is it your shade?

### 6. Bridge to school

The same bottles appear with the fractions written beside them, then the bottles fade and the notation stays:

¾ = 6⁄8 = 9⁄12

Then two questions in the form used in class:

- Complete: ¾ = ?⁄8
- Are ½ and 5⁄10 equal?

The Tutor says plainly: "This is what it looks like on a worksheet. It is the same thing you did with the bottles."

### What code does and what the Tutor does

| Code | Tutor |
| --- | --- |
| Draws the bottle and computes the swatch colour from the mix | Sets the scene and speaks in the child's language |
| Decides whether two fractions are equal | Asks what the child noticed |
| Generates the practice cases and checks every answer | Chooses the next case, easier after a struggle |
| Records what was mastered | Notes what helped, for the profile |

### What it adapts to

- **A low check-in today:** only steps 1 to 3, as play, with no naming and no bridge.
- **Reading difficulty:** all text is read aloud, and each screen has one sentence.
- **Fear of being wrong:** no answer is ever marked wrong. The swatch shows the result and the child adjusts.

### Screens and input

Lessons run on a phone, a tablet, and a computer, in the app or in a browser. See the web decision in [DECISIONS.md](DECISIONS.md).

- Every action works by touch and by mouse. A tap and a click do the same thing. Nothing depends on hovering, a right click, or a keyboard shortcut.
- The game area scales to the screen and keeps its proportions. A larger screen shows a larger bottle, not more text.
- The rule of one sentence per screen holds on every screen size.

## Next lessons in fractions

2. Which bottle is pinker: comparing fractions
3. Half a bottle of a shade: a fraction of an amount
4. Blending two shades: adding fractions

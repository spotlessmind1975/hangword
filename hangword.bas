''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'' Hangword!
''
'' Official binary distribution of Hangword! at:
'' https://spotlessmind1975.itch.io/hangword
''
'' This version repository at:
'' https://github.com/spotlessmind1975/hangword
''
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
''
'' Hangword! is licensed under the Apache License, Version 2.0 (the "License");
'' you may not use this file except in compliance with the License.
'' You may obtain a copy of the License at
''
'' http://www.apache.org/licenses/LICENSE-2.0
''
'' Unless required by applicable law or agreed to in writing, software 
'' distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
'' WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
'' License for the specific language governing permissions and limitations 
'' under the License.
''
'''---------------------------------------------------------------------------
''' INITIALIZATION PHASE
'''---------------------------------------------------------------------------

' The first pragma command is used to make the compiler more strict about 
' the use of variables. Using this option, the compiler will stop with an 
' error if the variable is used without being previously defined with a 
' DIM (or VAR) command.

OPTION EXPLICIT

' Then, it is necessary to apply some techniques to reduce the memory actually 
' used, so that the game can run even on rather limited platforms.

' Next, we use this pragma to make SOUND commands synchronous with the 
' execution: it means that the sound will be played entirely before 
' continuing execution.

DEFINE AUDIO SYNC
	
' No we enable the RLE compression of the images, if available.

DEFINE COMPRESSION RLE ON

' Let's proceed to reduce the space occupied by dynamic strings. 
' In ugBASIC this space, despite being dynamic, is statically allocated 
' and occupies a certain memory space. With this pragma we tell ugBASIC 
' that we will never use more than 128 bytes to manage (dynamic) strings. 
' Static strings, such as those in quotes, don't count.
	
DEFINE STRING SPACE 128
	
' We also reduce the number of (dynamic) strings that can exist at any 
' given time, to a maximum of 64.
	
DEFINE STRING COUNT 64

' This other pragma asks ugBASIC to reduce the footprint of the
' generated code, excluding everything that is not used except 
' that which is valid for the (only) graphics mode that will be used. 
' In other words, with this command it will not be possible to use 
' different graphics modes in the same program. On the other hand, 
' you will get a fair improvement in the memory occupation of the code.	
	
DEFINE SCREEN MODE UNIQUE

' We enable the "bitmap" graphics mode. This is the mode in which 
' each individual pixel can be addressed individually, via primitive 
' commands, such as those related to drawing entire images. The (16)
' means that we could have up to 16 colors.

BITMAP ENABLE(16)

' We set the border color to black, at least for those targets for 
' which this instruction makes sense. Since ugBASIC is an isomorphic 
' language, it does not provide an abstraction of the concept of 
' "border". Therefore, if the border exists, it will be colored, 
' otherwise this statement corresponds to a "no operation".

COLOR BORDER BLACK
	
' The words are defined here, in the include file.

' uncomment this for ENGLISH NR. 1 dictionary
INCLUDE resources/words_english_001.bas
' uncomment this for ENGLISH NR. 2 dictionary
' INCLUDE resources/words_english_002.bas
' uncomment this for ENGLISH NR. 3 dictionary
' INCLUDE resources/words_english_003.bas

' uncomment this for ITALIANO NR. 1 dictionary
' INCLUDE resources/words_italian_001.bas
' uncomment this for ITALIANO NR. 2 dictionary
' INCLUDE resources/words_italian_002.bas
' uncomment this for ITALIANO NR. 3 dictionary
' INCLUDE resources/words_italian_003.bas

' Define variable is a very useful practice to ensure that the 
' memory space occupied is as optimized as possible. In 
' this specific case, this variable is used to iterate, 
' and therefore it is important that it is defined as a 
' BYTE variable so that the increments and comparisons 
' are as fast as possible.

DIM i AS BYTE

' This variable will store the selected secret word.

DIM secretWord AS STRING

' This variable will store the part of the word that has been
' made visible by choosing the right letter.
	
DIM shownWord AS STRING

' This variable will store the number of tries up now.
	
DIM tries AS BYTE

' This variable will store the current score.

DIM score AS INT

' This variable take note if the player won.

DIM playerWin AS BYTE

' This variable will receive the letter from the player.

DIM letter AS STRING

' Variables used for images.

DIM background0 AS IMAGE, background1 AS IMAGE
DIM hangman0 AS IMAGE, hangman1 AS IMAGE
DIM hangman2 AS IMAGE, hangman3 AS IMAGE
DIM hangman4 AS IMAGE, hangman5 AS IMAGE
DIM hangman6 AS IMAGE

'''---------------------------------------------------------------------------
''' RESOURCE LOADING
'''---------------------------------------------------------------------------

' With ugBASIC it is possible to read graphic resources directly from the 
' modern format (PNG, JPG, BMP, and so on), as the compiler takes care of 
' converting them to the target format. To do this, automatic algorithms 
' take care of many important phases, such as (for example) the construction 
' of an optimized palette. For this reason, in addition to indicating the 
' name of the file from which to read the graphic resource, it is possible 
' to suggest to ugBASIC how to treat the various images. Finally, in those 
' cases where targets can benefit from dedicated resources, it is possible 
' to create a folder with the name of the target to store the specific version 
' for that target, which will be loaded instead of the standard one.

' In this case, we are going to read the image used to draw the gibbet.
' To save space, the image has been cropped into two parts, which are drawn 
' one below the other, and left aligned to each other.
'
' +------------------+   ----
' |                  |   background0
' |  +---------------+   ----
' |  |
' |  |
' |  |
' |  |                   background1
' |  |
' |  |
' +--+                   ----

background0 := LOAD IMAGE("resources/background0.png")
background1 := LOAD IMAGE("resources/background1.png")

' Again, since the dimensions can vary from piece to piece, and because 
' some overlap with others, it was chosen to read them all separately.
' This is the meaning of the index:
'
'                 +----+ ----
'                 |    | head = 0 or 6
'                 +----+ ----
'                  /||\  arms = 1, 2 or 3
'                 / || \
'                   ||   ----
'                  /  \  legs = 4 or 5
'                 /    \

hangman0 := LOAD IMAGE("resources/hangman0.png")
hangman1 := LOAD IMAGE("resources/hangman1.png")
hangman2 := LOAD IMAGE("resources/hangman2.png")
hangman3 := LOAD IMAGE("resources/hangman3.png")
hangman4 := LOAD IMAGE("resources/hangman4.png")
hangman5 := LOAD IMAGE("resources/hangman5.png")
hangman6 := LOAD IMAGE("resources/hangman6.png")

'''---------------------------------------------------------------------------
''' CONSTANT (AND POSITION CALCULATION)
'''---------------------------------------------------------------------------

' Once the graphic resources have been loaded, each of which may have specific
' dimensions related to the type of machine used, we can calculate a series of
' constants that we will use to draw objects on the screen. The advantage of 
' using constants is that they are calculated once and for all by the 
' compiler and they do not take up space on the executable, as they are used 
' directly in the generated code. Note that we not only define a constant, 
' but we require ugBASIC to verify that its value is greater than zero. 
' This check is essential because it is possible that the resolution of the 
' chosen target is not sufficient to maintain all the graphic elements. 
' In this way, the compilation will be interrupted if the game cannot be 
' executed due to exceeding the graphic limits.

' This is the overall scaling for the images used. We use two sets of images,
' one "small" (80 pixel based) and one "large" (160 pixel based). We use one 
' or the other on a target basis.
	
CONST scale = IF ( IMAGE WIDTH( background0 ) > 80, 2, 1 )

' This is the horizontal offset to apply to the hangman picture.
' It is based on scaling of the images.

CONST hOffset = IF ( IMAGE WIDTH( background0 ) > 80, 0, -4 )

' This is the horizontal position to use, to move the gibbet at the center 
' of the screen.

CONST centerScreenX = ( SCREEN WIDTH - IMAGE WIDTH( background0 ) ) / 2

' These are the coordinates to use to draw the hangman. The abscissa
' is equal to each section, while the ordinate is different for head,
' arms and legs.

CONST hangmanX = centerScreenX+32*scale+hOffset
CONST hangmanY = 22*scale
CONST hangmanY2 = hangmanY+IMAGE HEIGHT( hangman0 )
CONST hangmanY3 = hangmanY2+IMAGE HEIGHT( hangman3 )

' This variable will store the column where to start to
' print the secret word, in a such way that it will be 
' centered on the screen.

POSITIVE CONST centerWordX = _
	IF ( ( ( COLUMNS - wordLen ) / 2 ) < 0, _
		0, _
		( ( COLUMNS - wordLen ) / 2 ) _
		)

' This is the actual size of the font used to print
' text on the screen, and other pre-calculated sizes.

CONST fontHeight = FONT HEIGHT
CONST fontWidth = FONT WIDTH
CONST fontHeightMinus2 = FONT HEIGHT - 2
CONST fontWidthMinus2 = FONT WIDTH - 2

' Titles to show on the title screen. Note that we change the actual
' strings based on the fact that it is possible to print them on
' the screen, since there are enough columns.

CONST title0 = "Hangword!"
CONST title1 = IF( COLUMNS > 15, "by M.Spedaletti", "M.Spedaletti" )
CONST title2 = IF( COLUMNS > 17, "for RPI Challenge", "RPI Challenge")

' Vertical position of each title. Note that we calculate dinamically
' the vertical ordinates based on graphical elements and screen resolution.
' So we calculate the vertical spacing.

POSITIVE CONST titleY = _
						( _
							IMAGE HEIGHT( background0 ) + _
					  		IMAGE HEIGHT( background1 ) _
					  	) / FONT HEIGHT
					  	
POSITIVE CONST titleSpacing = _
						IF ( _
							( ROWS - titleY ) / 4 > 0, _
							( ROWS - titleY ) / 4, _
							1 _
						)
						
POSITIVE CONST titleY0 = titleY + titleSpacing
POSITIVE CONST titleY1 = titleY0 + titleSpacing
POSITIVE CONST titleY2 = titleY1 + titleSpacing

' Calculate the vertical position for "Game Over" string.
' We should put it on the center of the screen, but
' if was already used, we will move it just two lines above.

POSITIVE CONST gameOverY = _
						IF ( _
							( ROWS / 2 ) = titleY0, _
							titleY0 - 2, _
							ROWS / 2 _
						)

' Finally, calculate the position of "DICTIONARY" name.

POSITIVE CONST wordCountingX = (COLUMNS - LEN(wordName)) / 2
POSITIVE CONST wordCountingY = ( ROWS / 2 ) - 2

'''---------------------------------------------------------------------------
''' PROCEDURES
'''---------------------------------------------------------------------------

' This procedure must be used to extract a specific feature from the 
' (actual) dictionary of features.

PROCEDURE extractLetters[ _index ]

	' Re-use the global iteration variable, to save space.
	
	SHARED i

	' Use these variables to store the computation
	' of feature-to-segment conversion.
	
	DIM a AS BYTE, b AS BYTE, b1 AS BYTE, b2 AS BYTE, c AS BYTE
	
	' Use these variables to store the encoded feature.
	
	DIM feature1 AS BYTE, feature2 AS BYTE 
	
	' Use this variable to store the decoded feature (segment)
	
	DIM segment AS STRING
	
	' Move to the start of the features
	
	RESTORE features
	
	' Move to the destination feature in the features.
	' Note that we could directly access the feature of interest, 
	' using the dynamic version of the RESTORE command. However, 
	' by doing so, we would occupy a space proportional to all 
	' possible features. Furthermore, sequential reading is very 
	' fast anyway, and therefore the savings would be negligible.
	
	DO
		' We use READ FAST in order to avoid runtime DATA type
		' detection. You must use DATA FAST if you use DATA AS ....
		READ FAST feature1, FAST feature2
		EXIT IF _index = 0
		DEC _index
	LOOP

	' Now extract the letters starting from the feature data.
	' We are using the "\" and "**" operators to use the
	' power of 2 optimized version of multiplications and divisions.
	
	a = feature1 \ 8
	b1 = ( ( feature1 AND 7 ) ** 4 )
	b2 = ( feature2 \ 32 )
	b = b1 OR b2
	c = feature2 AND &H1F

	' This will recostruct the letters, 
	' starting from the feature's value.
	
	segment =  CHR$(65+a) + CHR$(65+b) + CHR$(65+c)
	
	RETURN segment

END PROCEDURE

' This procedure can be used to extract a new, random, word. The procedure
' will implement the MSC2 algorithm decompresso, that will read the informations
' stored into the DATA lines and extract a nn-letter word in a specific
' language. The compressor is a bit complex to be explained in short, 
' please refer to the dedicated page.

PROCEDURE extractSecretWord

	' This will be the secret word extracted, 
	' and shared with the program.
	
	SHARED secretWord

	' These variables will contains the feature
	' indexes of a word. Each word is composed
	' by juxtaposition of three or four 3-letters segments, 
	' and each segment will be retrieved by the
	' features using the classification identifier.
	
	DIM c1 AS BYTE, c2 AS BYTE, c3 AS BYTE, c4 AS BYTE
	
	' This variables will be used to store the number
	' of elements inside a specific feature group (cn1)
	' and subgroup (cn2).
	
	DIM cn1 AS BYTE, cn2 AS BYTE
	
	' This variable will be used to store the number
	' of the word randomly selected.
	
	DIM dictionaryWord AS WORD

	' Initialize the random word, from 1 to 2048.
	
	dictionaryWord = ( RANDOM WORD \ 32 ) + 1
	
	' Let's start from the beginning of the available words.
	
	RESTORE words
	
	' Let's move ahead.
	
	DO
	
		' Read the prefix of the group of features, and its size.
		
		READ FAST cn1, FAST c1


		DO
		
			' Read the prefix of the subgroup of features, and its size.
		
			READ FAST cn2, FAST c2

			DO
			
				' Read the feature content (1 or 2 additional suffixes).
				
				READ FAST c3
				
				IF wordLen = 12 THEN
					READ FAST c4
				ENDIF

				' Decrement the number of elements present in this subgroup.
				
				DEC cn2
	
				' Decrement the number of randomly selected word.
				
				DEC dictionaryWord		
		
				' If the subgroup is finished, move to the next.
				
				EXIT IF cn2 = 0
	
				' If the word is the one interested, exit.
				
				EXIT IF dictionaryWord = 0

				
			LOOP
			
			' Decrement the number of elements present in this group.
			
			DEC cn1 
			
			' If the group is finished, move to the next.
			
			EXIT IF cn1 = 0			
			
			' If the word is the one interested, exit.

			EXIT IF dictionaryWord = 0					

		LOOP

		' If the word is the one interested, exit.
			
		EXIT IF dictionaryWord = 0
		
	LOOP

	' Actually we have the feature indexes inside
	' the c1...c4 variables. So let's decode each
	' segment into 3 letters (4 x 3 letters = 12 letters)

	secretWord = extractLetters[c1]
	secretWord = secretWord + extractLetters[c2]
	secretWord = secretWord + extractLetters[c3]
	IF wordLen = 12 THEN
		secretWord = secretWord + extractLetters[c4]
	ENDIF
	
	' Transform the string in a lowercase format,
	' to be able to compare in a normalized way.
	
	secretWord = LOWER(secretWord)

END PROC

' Draw the (sad) head of the hangman.

PROCEDURE drawHangmanHeadGood
	SHARED hangman0
	PUT IMAGE hangman0 AT hangmanX, hangmanY
END PROC

' Draw the (dead) head of the hangman.

PROCEDURE drawHangmanHeadBad
	SHARED hangman6	
	PUT IMAGE hangman6 AT hangmanX, hangmanY
END PROC

' Draw the body of the hangman (without arms).

PROCEDURE drawHangmanBodyOnly
	SHARED hangman1	
	PUT IMAGE hangman1 AT hangmanX, hangmanY2
END PROC

' Draw the body of the hangman (with right arm).

PROCEDURE drawHangmanBodyRightArm
	SHARED hangman2
	PUT IMAGE hangman2 AT hangmanX, hangmanY2
END PROC

' Draw the body of the hangman (with both arms).

PROCEDURE drawHangmanBodyArms
	SHARED hangman3
	PUT IMAGE hangman3 AT hangmanX, hangmanY2
END PROC

' Draw the legs of the hangman (only right)

PROCEDURE drawHangmanRightLeg
	SHARED hangman4
	PUT IMAGE hangman4 AT hangmanX, hangmanY3
END PROC

' Draw the legs of the hangman (both)

PROCEDURE drawHangmanLegs
	SHARED hangman5
	PUT IMAGE hangman5 AT hangmanX, hangmanY3
END PROC

' Draw the entire hangman 

PROCEDURE drawHangman
	
	' Share the actual number of wrong letters.
	
	SHARED tries
	
	' Draw differently based on "tries" variable.
	
	SELECT CASE tries
		CASE 0
			' NO TRIES - Draw nothing.
		CASE 1
			' 1 WRONG TRY - Draw head only.
			drawHangmanHeadGood[]
		CASE 2
			' 2 WRONG TRIES - Draw head and body (only, no arms)
			drawHangmanHeadGood[]
			drawHangmanBodyOnly[]
		CASE 3
			' 3 WRONG TRIES - Draw head and body (with right arm)
			drawHangmanHeadGood[]
			drawHangmanBodyRightArm[]
		CASE 4
			' 4 WRONG TRIES - Draw head and body (with both arms)
			drawHangmanHeadGood[]
			drawHangmanBodyArms[]
		CASE 5
			' 5 WRONG TRIES - Draw head and body and right leg
			drawHangmanHeadGood[]
			drawHangmanBodyArms[]
			drawHangmanRightLeg[]
		CASE 6
			' 6 WRONG TRIES - Draw head and body and both legs
			drawHangmanHeadGood[]
			drawHangmanBodyArms[]
			drawHangmanLegs[]
		CASE 7
			' 7 WRONG TRIES - Draw (dead) head and body and both legs
			drawHangmanHeadBad[]
			drawHangmanBodyArms[]
			drawHangmanLegs[]
	ENDSELECT

END PROC

' Draw the gibbet

PROCEDURE drawGibbet
	SHARED background0, background1
	PUT IMAGE background0 AT centerScreenX, 0
	PUT IMAGE background1 AT centerScreenX, IMAGE HEIGHT( background0 )
END PROC

' This procedure will print the score under the word.

PROCEDURE drawScore

	' Share the actual score to print.
	
	SHARED score
	
	LOCATE centerWordX, titleY1
	INK COLOR(3)
	PRINT "           ";
	CENTER "score "+STR(score);
	
END PROC

' This procedure will show the word to guess.

PROCEDURE showWord

	' Share the secret word and the show word.
	
	SHARED secretWord, shownWord, i
	
	DIM xCurs AS BYTE, yCurs AS BYTE
	
	' This variable will take note of the any guessed letter.
	
	DIM shownLetter AS STRING
		
	LOCATE centerWordX, titleY0
	INK COLOR(3)
	
	' Now we are going to draw the word, one letter at a time.
	
	i = 1
	
	DO
	
		' Take the i-nth letter.
		shownLetter = MID$(shownWord, i, 1)
		
		' Update the cursor position.
		LOCATE centerWordX + i - 1, titleY0
		
		' If the letter has not been guessed...
		IF shownLetter = " " THEN
		
			' ... we draw a line. Note that we use the DRAW
			' command instead of underscore character, since
			' it could not be present in the target's font.
			' The line will be drawed using the current cursor
			' position. 

			xCurs = XCURS 
			xCurs = xCurs ** #fontWidth
			yCurs = YCURS
			yCurs = ( yCurs ** #fontHeight ) + fontHeightMinus2
			
			DRAW xCurs, yCurs TO xCurs+fontWidthMinus2, yCurs
			
		ELSE
		
			' ... otherwise, we can draw the letter, directly!
			
			PRINT shownLetter;
			
		ENDIF
		
		EXIT IF i = wordLen
		
		INC i
		
	LOOP

END PROC

'''---------------------------------------------------------------------------
''' MAIN GAME LOOP
'''---------------------------------------------------------------------------

' Clear the screen to black.

CLS BLACK

' TITLE SCREEN

' Draw the gibbet and the hangman.

drawGibbet[]
tries = 6
drawHangman[]

' Draw the titles.

INK COLOR(3)
LOCATE , titleY0
CENTER title0
LOCATE , titleY1
CENTER title1
LOCATE , titleY2
CENTER title2;

' Wait user to press any key.

WAIT KEY

' Choose a random value, based on the time elapsed
' waiting the key press.

RANDOMIZE TIMER*100

DO

	' Clear again the screen.
	
	CLS
	
	' Begin a new game by resetting the number of attempts.
	
	tries = 0
	
	' Print the name of the dictionary for this edition.
	
	LOCATE wordCountingX, wordCountingY
	CENTER "dictionary:"
	LOCATE wordCountingX, wordCountingY+2
	CENTER wordName
	
	' Play a .5 second sound.
	
	SOUND #440, #500

	' Extract a new (random) word.
	
	extractSecretWord[]
	
	' Clear the screen
	
	CLS
	
	' Draw the gibbet.  
	
	drawGibbet[]

	' First of all, let's create a string where we will keep track of the 
	' letters guessed. We will use the space to indicate the letters to guess.

	shownWord = "            "

	'''---------------------------------------------------------------------------
	''' MAIN PLAY LOOP
	'''---------------------------------------------------------------------------
	
		
	DO

		' Update the score
		
		drawScore[]
		
		' Update the drawing of the hangman.
		
		drawHangman[]
		
		' GAME OVER if more than 6 tries.
		
		EXIT IF tries > 6

		' Draw the word to guess. 
		
		showWord[]
		
		' The program halts is execution, in order to wait for
		' any letter pressed by the player.
		
		letter = LOWER(INPUT$(1))

		' The first check we do is very rapid: we check if the key pressed
		' has been already pressed.
		
		IF ( INSTR( shownWord, letter ) = 0 ) THEN
		
			' Then, we check if the letter has been used into the secret
			' word, since it means that the letter is correct.			
		
			IF ( INSTR( secretWord, letter ) > 0 ) THEN

				' +1 point!
				
				INC score
				
				' If it belongs to the secret string, we are going to replace
				' the space with the guessed char inside the visibile word's
				' string.
				
				i = 1
				
				DO
				
					IF MID$(secretWord, i, 1) = letter THEN
						' +1 point!
						MID$(shownWord, i, 1) = letter
						INC score
					ENDIF
					
					EXIT IF i = wordLen
					
					INC i
					
				LOOP
				
				' If the entire visibile string is equal to the secret word,
				' we can end the game!
				
				IF shownWord = secretWord THEN
					playerWin = TRUE
				ENDIF
				
			ELSE
			
				' Sorry, the letter is wrong: play a little music
				' and increase the tries.
				
				SOUND #440, #250
				SOUND #480, #250
				SOUND #540, #250
				INC tries
				
			ENDIF

		ELSE
		
			' Sorry, the letter is wrong: play a little sound
			
			SOUND #440, #250
		
		ENDIF

		' Exit if the player wins.
		
		EXIT IF playerWin
		
	LOOP

	' Change the exit message based on the fact that
	' the player won or not.

	LOCATE , gameOverY
	INK COLOR(2)
	IF playerWin THEN
		ADD score, 24
		CENTER " YOU WIN! "
	ELSE
		score = score - 6
		IF score < 0 THEN
			score = 0
		ENDIF
		CENTER "GAME OVER!"
	ENDIF

	' In both events, we draw out the secret word.
	
	INK COLOR(3)
	LOCATE centerWordX, titleY0
	INK COLOR(2)
	PRINT secretWord;

	' Update the score on the screen.
	drawScore[]

	WAIT KEY RELEASE
	
LOOP
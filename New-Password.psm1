<##
 # Copyright 2021 David Hollings. All rights reserved.
 # Use of this source code is governed by a BSD-style
 # license that can be found in the LICENSE file.
#>

#Import Helper Scripts
. $PSScriptRoot/Private/vars.ps1
. $PSScriptRoot/Private/GetEntropy.ps1

Function New-Password {
    <#
    .SYNOPSIS
        Generate a random password either using random words (XKCD format) or a random character string.
    .DESCRIPTION
        Generate a random password using user-specified parameters. Supports either a random string or a word list.
        While characters are faster to generate they may be harder to remember so are best suited to service accounts
        or other systems where they are less likely to be entered manually. By default Character mode uses all alphanumeric
        characters and punctuation but can be customised.
        Word formatted passwords support a custom number of words and optional padding digits at the beginning and end. Word case is randomised to increase entropy. There will not be an option to customise word case.
        The word list cannot be specified at the command line but new wordlists can be imported using the Import-PSPwUtilsWordList cmdlet.
    .INPUTS
        None
    .OUTPUTS
        System.Management.Automation.PSCustomObject
    .EXAMPLE
        PS> New-Password -Length 30 -Characters Lower,Upper,Number

        Password                       BlindEntropy SeenEntropy
        --------                       ------------ -----------
        X3EP14IvBHwPjTWqC5wJsYwDFSaDYL          179         179

        Generates a 30 digit random password using lower and upper case letters and numbers

    .EXAMPLE
        PS> New-Password -Word

        Password                          BlindEntropy SeenEntropy
        --------                          ------------ -----------
        PURGING?spirits?maternal?DIVINITY          211          59

        Generates a new words type passphrase using default parameters

    .EXAMPLE
        PS> New-Password -Words 5 -PrefixDigits 1 -SuffixDigits 3 -PrefixSymbols 2 -SuffixSymbols 1 -SeparatorCharacters "_"

        Password                                              BlindEntropy SeenEntropy
        --------                                              ------------ -----------
        &[_3_CRAFTER_conclude_DEFERRAL_SCRUFFY_EXPORTER_887_=          347          96

        Generate a 5 word password with 2 prefix symbols, 1 suffix symbol, 1 prefix digt and 3 suffix digits. Words are separated by underscores

    .EXAMPLE
        PS> New-Password -MinimumLength 6 -MaximumLength 9 -Count 4 -SeparatorCharacters "-_=+/\"

        Password                             BlindEntropy SeenEntropy
        --------                             ------------ -----------
        coronary+AVERAGE+endurable+COLONIZE           224          56
        MOUSINESS\married\atrocious\smelting          230          56
        unsavory=THROWBACK=HARMONY=corporal           224          56
        ANOTHER/RIMLESS/UNCOATED/CAREFULLY            199          56

        Generate 4 passphrases using words containg between 6 and 9 letters. Separator character is randomly chosen from -, _, =, +, / and \

    .EXAMPLE
        PS> New-Password | Publish-Password

        Password  : Mr?)wrP8+>JoC&YdZ&<e
        Days      : 7
        Views     : 5
        Deletable : True
        Link      : https://pwpush.com/p/s0cbre91fkkjz6oo

        Generate a random password and create a sharable link using PwPush

    .LINK
        https://github.com/davidshomelab/PS-PwUtils
    #>
    [CmdletBinding(DefaultParameterSetName = "Character")]
    param(
        # Generate a Character password (Default).
        [Parameter(ParameterSetName = "Character")]
        [switch]
        $Character,

        #Number of characters to use in character password.
        [Parameter(ParameterSetName = "Character")]
        [ValidateRange(4, 255)]
        [int]
        $Length = 20,

        #Character set to use when generating character passwords.
        [Parameter(ParameterSetName = "Character")]
        [ValidateSet("Upper","Lower","Number","Symbol")]
        [string[]]
        $Characters = @("Upper","Lower","Number","Symbol"),

        # Generate a Word passphrase.
        [Parameter(ParameterSetName = "Word")]
        [switch]
        $Word,

        #Number of words to use in Word password.
        [Parameter(ParameterSetName = "Word")]
        [ValidateRange(1,14)]
        [int]
        $Words = 4,

        #Minimum length of words to use in Word password.
        [Alias("MinLength")]
        [Parameter(ParameterSetName = "Word")]
        [ValidateRange(4, 15)]
        [int]
        $MinimumLength = 4,

        #Maximum length of words to use in password.
        [Alias("MaxLength")]
        [Parameter(ParameterSetName = "Word")]
        [ValidateScript( {
                $_ -ge $MinimumLength -and $_ -le 15
            })]
        [int]
        $MaximumLength = 15,

        # Number of digits at beginning of password.
        [Parameter(ParameterSetName = "Word")]
        [ValidateRange(0,10)]
        [int]
        $PrefixDigits = 0,

        # Number of digits at end of password.
        [Parameter(ParameterSetName = "Word")]
        [ValidateRange(0,10)]
        [int]
        $SuffixDigits = 0,
        
        # String of characters to be used as separator character. One character in the string will be chosen at random. Duplicate values will be removed prior to processing.
        [Parameter(ParameterSetName = "Word")]
        [string]
        $SeparatorCharacters = $Symbols,

        # Number of random symbols at beginning of password.
        [Parameter(ParameterSetName = "Word")]
        [ValidateRange(0,10)]
        [int]
        $PrefixSymbols = 0,

        # Number of random symbols at end of password.
        [Parameter(ParameterSetName = "Word")]
        [ValidateRange(0,10)]
        [int]
        $SuffixSymbols = 0,

        # Character set for padding symbols. Provide the list of symbols as a string. Duplicate values will be removed prior to processing.
        [Parameter(ParameterSetName = "Word")]
        [string]
        $PaddingSymbols = $Symbols,

        # Generate the password as a secure string. True by default if the output is piped to another cmdlet, false if run as a standalone cmdlet.
        [Parameter()]
        [switch]
        $AsSecureString = $(if ($PSCmdlet.MyInvocation.PipelineLength -gt 1){$true}else {$false}),

        # How many passwords to generate
        [Parameter()]
        [int]
        $Count = 1
    )

    Write-Verbose "Generating $Count Passwords"
    Write-Verbose "Method: $($PSCmdlet.ParameterSetName)"
    if ($PSCmdlet.ParameterSetName -eq "Character"){
        Write-Verbose "Character Count: $Length"
        Write-Verbose "Permitted Character Categories: $Characters"

    }
    if ($PSCmdlet.ParameterSetName -eq "Word") {
        Write-Verbose "Words: $Words"
        Write-Verbose "Minumum Length: $MinimumLength"
        Write-Verbose "Maximum Length: $MaximumLength"
        Write-Verbose "Prefix Digits: $PrefixDigits"
        Write-Verbose "Suffix Digits: $SuffixDigits"
        Write-Verbose "Prefix Symbol Count: $PrefixSymbols"
        Write-Verbose "Suffix Symbol Count: $SuffixSymbols"
        Write-Verbose "Padding Symbol Characters: $PaddingSymbols"
        Write-Verbose "Separator Symbol Characters: $SeparatorCharacters"
        
    }

    if ($PSCmdlet.ParameterSetName -eq "Word") {
        # Import WordList. In the event that count is greater than 1 and we want a Words type password,
        # we import the dictionary outside the loop as it only needs to be done once
        $Wordlist = Import-Clixml $PSScriptRoot\words.xml
        $AvailableWords = New-Object -TypeName System.Collections.ArrayList
        for ($CurrentWordLength = $MinimumLength ; $CurrentWordLength -le $MaximumLength; $CurrentWordLength ++){
            Write-Verbose "Importing words of length $CurrentWordLength"
            Write-Debug "$($Wordlist[$CurrentWordLength])"
            $AvailableWords += $Wordlist[$CurrentWordLength] 
        }
        $WordlistLength = $AvailableWords.Length
        Write-Verbose "Found $WordlistLength available words"
        if ($WordlistLength -le 100){
            throw "Not enough available words, try setting less restrictive minimum and maximum lengths."
        }

        # Deduplicate separator characters
        $DeduplicatedSeparatorCharacters = ([char[]]$SeparatorCharacters | Select-Object -Unique) -join ""
        if ($SeparatorCharacters.Length -ne $DeduplicatedSeparatorCharacters.Length){
            Write-Verbose "Duplicate separator characters found. Deduplicating."
        }
        
        # Deduplicate padding symbols
        $DeduplicatedPaddingSymbols = ([char[]]$PaddingSymbols | Select-Object -Unique) -join ""
        if ($PaddingSymbols.Length -ne $DeduplicatedPaddingSymbols.Length){
            Write-Verbose "Duplicate separator characters found. Deduplicating."
        }
    }

    if ($PSCmdlet.ParameterSetName -eq "Character"){
        if ("Lower" -in $Characters){
            $AvailableCharacters += $LowerCase
        }
        if ("Upper" -in $Characters){
            $AvailableCharacters += $UpperCase
        }
        if ("Number" -in $Characters){
            $AvailableCharacters += $Numbers
        }
        if ("Symbol" -in $Characters){
            $AvailableCharacters += $Symbols
        }
    }

    (1..$Count) | ForEach-Object {
        if ($PSCmdlet.ParameterSetName -eq "Character") {
            $CharacterCount = $AvailableCharacters.Length
            $Password = ""
            (1..$Length) | ForEach-Object {
                $Random = Get-Random -Minimum 0 -Maximum $CharacterCount
                $SelectedCharacter = $AvailableCharacters[$Random]
                $Password += $SelectedCharacter
            }

            $EntropyParams = @{} # We will add parameters to this array later but for now just need to ensure it exists

        }


        # Word password
        else {

            # Initialise array to contain password components
            [string[]]$PasswordWords = @()

            # Generate prefix symbols
            if ($PrefixSymbols -gt 0){
                $PasswordWords += GenerateCharstring -Length $PrefixSymbols -Charset $DeduplicatedPaddingSymbols
            }

            # Generate prefix digits
            if ($PrefixDigits -gt 0){
                $PasswordWords += GenerateCharstring -Length $PrefixDigits -Charset $Numbers
            }

            # Generate $Words random words and add them to oputput array. Word case is decided randomly
            (1..$Words) | ForEach-Object {
                $Random = Get-Random -Minimum 0 -Maximum $AvailableWords.Length
                $SelectedWord = $AvailableWords[$Random]
                if ((Get-Random -Minimum 0 -Maximum 2) -eq 1) {
                    $SelectedWord = $SelectedWord.ToUpper()
                }
                $PasswordWords += $SelectedWord
            }

            # Generate suffix digits
            if ($SuffixDigits -gt 0){
                $PasswordWords += GenerateCharstring -Length $SuffixDigits -Charset $Numbers
            }

            # Generate suffix symbols
            if ($SuffixSymbols -gt 0){
                $PasswordWords += GenerateCharstring -Length $SuffixSymbols -Charset $DeduplicatedPaddingSymbols
            }

            # Choose separator character
            if ($DeduplicatedSeparatorCharacters.Length -gt 1) {
                $SeparatorIndex = Get-Random -Minimum 0 -Maximum ($DeduplicatedSeparatorCharacters.Length)
                $SeparatorCharacter = $DeduplicatedSeparatorCharacters[$SeparatorIndex]
            }
            else { $SeparatorCharacter = $DeduplicatedSeparatorCharacters }



            # Print final password
            $EntropyParams = @{
                Word = $true
                WordListLength = $WordlistLength
                WordCount = $Words
                PrefixSymbolCount = $PrefixSymbols
                SuffixSymbolCount = $SuffixSymbols
                SymbolSetSize = $DeduplicatedPaddingSymbols.Length
                PrefixDigitCount = $PrefixDigits
                SuffixDigitCount = $SuffixDigits
                SeparatorCharacterCount = $DeduplicatedSeparatorCharacters.length
            }

            $Password = $PasswordWords -join $SeparatorCharacter

        }

        # Convert password to secure string to pass to GetEntropy
        $SecurePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force

        #Add password to EntropyParams. We do this here because both string and word format passwords use this field
        $EntropyParams.Password = $SecurePassword

        if ($AsSecureString){
            $Password = $SecurePassword
        }

        $Entropy = GetEntropy @EntropyParams
        $Output = [PSCustomObject]@{
            Password = $Password
            BlindEntropy = $Entropy.BlindEntropy
            SeenEntropy = $Entropy.SeenEntropy
        }

        Write-Output $Output

    }
}
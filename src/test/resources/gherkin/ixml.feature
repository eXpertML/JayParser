Feature: Invisible XML Parse function Compliance

  Invisible XML is a grammar language designed to render a string parsed with a given grammar as an XML tree.

  This documents the tests that prove a parse function renders the correct result according to the Invisible XML Specification.  It attempts to do so using the Gherkin format, so that implementors can convert these tests to the BDD framework of their choice.

  The arguments given in the Examples tables below are literal strings and file names which should either be read as a string (quote escaped text), read to a string (*.txt), interpreted as a grammar definition (*.ixml), opened as an XML instance (*.xml), or as an XML instance which is itself a grammar definition (*.xml in the grammar column).  Some arguments may be empty (i.e. to show that no error is thrown, or no output is given).

  Scenario Outline: Parse With Grammar
    Given a <string>
    And a <grammar>
    Then the parse function should an XML node with the following <value> for a given <xpath>:

    Examples:
    |  string    |  grammar   |  value     |  xpath  |
    |  ixml.txt  |  ixml.xml  |  ixml.xml  |  "/"    |

  Scenario Outline: Grammar is not a valid grammar
    Given an invalid <grammar>
    And a <string>
    Then the parser should throw the error <err> and return the <output>

    Examples:
    |  string  |  grammar  |  err  |  output  |

  Scenario Outline: String is not valid to the Grammar
    Given a <grammar>
    And an invalid <string>
    Then the parser should throw the error <err> and return the <output>

    Examples:
    |  string  |  grammar  |  err  |  output  |
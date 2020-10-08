<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:xs="http://www.w3.org/2001/XMLSchema"
	xmlns:math="http://www.w3.org/2005/xpath-functions/math"
  xmlns:e="http://schema.expertml.com/JayParser"
  xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
	exclude-result-prefixes="xs math e map xd"
	version="3.0">
	
	<xd:doc scope="stylesheet">
		<xd:desc>
			<xd:p><xd:b>Created on:</xd:b>2020-09-23</xd:p>
			<xd:p><xd:b>Author:</xd:b> Tomos FJ Hillman (TFJH)</xd:p>
			<xd:p>This stylesheet is an Earley-like Parser designed to parse invisible XML grammars.</xd:p>
			<xd:p>It does this by constructing a tree of possible (partial) parses from the grammar, then pruning that tree to find a suitable parse, if one exists.</xd:p>
		</xd:desc>
		<xd:param name="input">The string to be parsed</xd:param>
		<xd:param name="grammar">An invisible XML grammar (as XML); the default stylesheet input is used if not specified.</xd:param>
	</xd:doc>
	
  <xsl:output indent="yes" method="xml"/>
	
  <xsl:param name="input" as="xs:string" select="'{a=0}'"/>
  <xsl:param name="grammar" as="document-node(element(ixml))" select="/"/>
	<xsl:param name="debug" as="xs:boolean" static="true" select="true()"/>
	
  <xsl:key name="ruleByName" match="rule" use="@name"/>
  
  <!-- initial templates -->
  <xd:doc>
    <xd:desc>This template exists to run the initial POC parse operation</xd:desc>
  </xd:doc>
  <xsl:template name="xsl:initial-template">
    <xsl:sequence select="e:parse($input)"/>
  </xsl:template>
	
	<!-- e:parseTree mode (used for building the parse tree) -->
	<xsl:mode name="e:parseTree" on-no-match="shallow-copy" on-multiple-match="use-last" warning-on-multiple-match="false"/>
	
	<xd:doc>
		<xd:desc>iXML root node match template: iXML defines the first rule to be the 'start' rule corresponding with the output root node.  This also intialises the $visited and $state tunnel parameters</xd:desc>
	</xd:doc>
	<xsl:template match="ixml" mode="e:parseTree">
		<xsl:variable name="result" as="map(*)?">
			<xsl:apply-templates select="rule[1]" mode="#current">
				<xsl:with-param name="visited" as="map(*)" select="map{}" tunnel="yes"/>
				<xsl:with-param name="state" as="xs:integer" select="1" tunnel="yes"/>
			</xsl:apply-templates>
		</xsl:variable>
		<xsl:comment use-when="$debug">
			Visited: <xsl:sequence select="serialize($result?visited, map{'method':'json', 'indent':true()})"/>
			States: 
				<xsl:for-each select="1 to count($result?states)">
					<xsl:variable name="this.num" select="." as="xs:integer"/>
					<xsl:variable name="next.num" select=". + 1" as="xs:integer"/>
					<xsl:variable name="this.state" select="$result?states[$this.num]" as="xs:string"/>
					<xsl:variable name="next.state" select="$result?states[$next.num]" as="xs:string?"/>
					<xsl:value-of select="$this.num"/>
					<xsl:text>: </xsl:text>
					<xsl:value-of select="substring-before($this.state, $next.state)"/>
					<xsl:text>&#xa;</xsl:text>
				</xsl:for-each>
		</xsl:comment>
		<xsl:sequence select="$result?parseTree"/>
	</xsl:template>
	
	<xd:doc>
		<xd:desc>rule and alts match template: this adds rules and/or an alternatives structure to the parse tree, returning a map including the 'parseTree', 'visited' and 'states'.</xd:desc>
    <xd:param name="state">The current state number</xd:param>
    <xd:param name="visited">The map of nonterminal rules visited, and associated states.</xd:param>
    <xd:param name="states">A sequence of existing states, ordered by state reference number</xd:param>
	</xd:doc>
	<xsl:template match="rule|alts" mode="e:parseTree" as="map(*)">
		<xsl:param name="state" tunnel="yes" as="xs:integer"/>
		<xsl:param name="visited" tunnel="yes" as="map(*)"/>
		<xsl:param name="states" tunnel="yes" as="xs:string+"/>
		<xsl:variable name="key" select="(@name, @gid, generate-id())[1]"/>
		<xsl:choose>
			<!-- when the rule has not yet been visited in this state -->
			<xsl:when test="e:unvisited($visited, $key, $state)">
				<xsl:variable name="result" as="map(*)">
					<xsl:call-template name="e:process-alt-siblings">
						<xsl:with-param name="visited" tunnel="yes" select="e:visit($visited, $key, $state)"/>
					</xsl:call-template>
				</xsl:variable>
				<xsl:map>
					<xsl:map-entry key="'parseTree'">
						<xsl:element name="e:{local-name()}">
							<xsl:attribute name="state" select="$state"/>
							<xsl:attribute name="ends" select="string-join($result?ends, ' ')"/>
							<xsl:apply-templates select="@*" mode="#current"/>
							<xsl:sequence select="$result?parseTree"/>
						</xsl:element>
					</xsl:map-entry>
					<xsl:map-entry key="'visited'" select="e:visit($result?visited, $key, $state, $result?ends)"/>
					<xsl:sequence select="map:remove($result, ('visited', 'parseTree'))"/>
				</xsl:map>
			</xsl:when>
			<!-- when the rule has been visited in this state, but fails -->
			<xsl:when test="not(exists($visited($key)(string($state))))">
				<xsl:map>
					<xsl:map-entry key="'parseTree'">
						<e:fail state="{$state}" nt="{$key}"/>
					</xsl:map-entry>
					<xsl:map-entry key="'visited'" select="$visited"/>
					<xsl:map-entry key="'states'" select="$states"/>
				</xsl:map>
			</xsl:when>
			<!-- when the rule has been visited in this state, and succeeds -->
			<xsl:otherwise>
				<xsl:map>
					<xsl:map-entry key="'parseTree'">
						<e:nt state="{$state}" name="{$key}"/>
					</xsl:map-entry>
					<xsl:map-entry key="'visited'" select="$visited"/>
					<xsl:map-entry key="'states'" select="$states"/>
					<xsl:map-entry key="'ends'" select="$visited($key)(string($state))"/>
				</xsl:map>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	
	<xd:doc>
		<xd:desc></xd:desc>
	</xd:doc>
	<xsl:template match="alt" mode="e:parseTree" as="map(*)">
		<xsl:variable name="result" as="map(*)">
			<xsl:call-template name="e:process-siblings"/>
		</xsl:variable>
		<xsl:map>
			<xsl:map-entry key="'parseTree'">
				<e:alt>
					<xsl:sequence select="$result?parseTree"/>
				</e:alt>
			</xsl:map-entry>
			<xsl:sequence select="map:remove($result, 'parseTree')"/>
		</xsl:map>
	</xsl:template>
	
	<xd:doc>
		<xd:desc>Adds nonterminal rules to the parseTree.</xd:desc>
		<xd:param name="grammar">The grammar used for the parse</xd:param>
	</xd:doc>
	<xsl:template match="nonterminal" mode="e:parseTree" as="map(*)">
		<xsl:param name="grammar" tunnel="yes"/>
		<xsl:apply-templates select="key('ruleByName', @name, $grammar)" mode="#current"/>
	</xsl:template>
	
	<xd:doc>
    <xd:desc>Processing of Character sets inclusions/exclusions.</xd:desc>
    <xd:param name="state">The current state reference</xd:param>
    <xd:param name="states">A sequence of existing states, ordered by state reference number</xd:param>
		<xd:param name="visited">A map of visited states</xd:param>
	</xd:doc>
	<xsl:template match="inclusion|exclusion|literal" mode="e:parseTree" as="map(*)">
    <xsl:param name="states" as="xs:string+" tunnel="yes"/>    
    <xsl:param name="state" as="xs:integer" tunnel="yes"/>
		<xsl:param name="visited" as="map(*)" tunnel="yes"/>
		<xsl:message use-when="$debug" select="'matching terminal of type '||local-name()||' in state '||$state||' for string &quot;'||substring($states[$state], 1, 10)||'&quot;'"/>
		<xsl:message use-when="$debug" select="."/>
		<xsl:variable name="seq" as="xs:string+">
			<xsl:text>^(</xsl:text>
			<xsl:apply-templates select="." mode="e:charSetRegEx"/>
			<xsl:text>).*?$</xsl:text>
		</xsl:variable>
		<xsl:variable name="regex" as="xs:string">
      <xsl:sequence select="string-join($seq, '')"/>
		</xsl:variable>
		<xsl:message use-when="$debug" select="'regex: '||$regex"/>
    <xsl:variable name="match" as="xs:boolean" select="matches($states[$state], $regex, 's')"/>
		<xsl:choose>
      <xsl:when test="$match">
    		<xsl:variable name="matched" select="replace($states[$state], $regex, '$1', 's')" as="xs:string"/>
        <xsl:variable name="remaining" select="substring-after($states[$state], $matched)"/>
        <xsl:variable name="altered.states" select="($states, $remaining[not($remaining = $states)])"/>
        <xsl:variable name="ends" select="index-of($altered.states, $remaining)" as="xs:integer*"/>
      	<xsl:map>
					<xsl:map-entry key="'parseTree'">
						<e:literal state="{$state}" ends="{if ($remaining eq '') then 0 else string-join($ends, ' ')}">
							<xsl:copy-of select="@tmark"/>
							<xsl:value-of select="$matched"/>
						</e:literal>
					</xsl:map-entry>
      		<xsl:map-entry key="'ends'" select="$ends"/>
      		<xsl:map-entry key="'states'" select="$altered.states"/>
      		<xsl:map-entry key="'visited'" select="$visited"/>
      	</xsl:map>
      </xsl:when>
      <xsl:otherwise>
				<xsl:map>
					<xsl:map-entry key="'parseTree'">
						<e:fail state="{$state}" regex="{$regex}"/>
					</xsl:map-entry>
					<xsl:map-entry key="'states'" select="$states"/>
					<xsl:map-entry key="'visited'" select="$visited"/>
				</xsl:map>
      </xsl:otherwise>
    </xsl:choose>
	</xsl:template>
  
  <xd:doc>
    <xd:desc>Template to create parse tree fragments for an optional repeat.  It does this by adding a choice between an empty parse result its content, as suggested in the iXML spec at https://homepages.cwi.nl/~steven/ixml/ixml-specification.html#L5773.  The resulting fragment is given a unique identifier to avoid infinite recursion and/or failed branches being duplicated.</xd:desc>
  </xd:doc>
  <xsl:template match="repeat0" mode="e:parseTree" as="map(*)">
    <xsl:variable name="GID" select="(@gid, local-name()||generate-id(.))[1]"/>
    <xsl:variable name="equivalent" as="element(alts)">
      <alts>
        <alt>
          <empty/>
        </alt>
        <alt>
					<repeat1 gid="{$GID}">
						<xsl:copy-of select="@*, node()"/>
					</repeat1>
        </alt>
      </alts>
    </xsl:variable>
  	<xsl:apply-templates select="$equivalent" mode="#current"/>
  </xsl:template>
  
  <xd:doc>
    <xd:desc>Template to create parse tree fragments for an optional rule.  It does this by adding a choice between an empty parse result its content, as suggested in the iXML spec at https://homepages.cwi.nl/~steven/ixml/ixml-specification.html#L5773.  The resulting fragment is given a unique identifier to avoid infinite recursion and/or failed branches being duplicated.</xd:desc>
  </xd:doc>
  <xsl:template match="option" mode="e:parseTree" as="map(*)">
    <xsl:variable name="GID" select="(@gid, local-name()||generate-id(.))[1]"/>
		<xsl:variable name="equivalent" as="element(alts)">
			<alts gid="{$GID}">
				<alt>
					<empty/>
				</alt>
				<alt>
					<xsl:sequence select="child::*"/>
				</alt>
			</alts>
		</xsl:variable>
  	<xsl:apply-templates select="$equivalent" mode="#current"/>
  </xsl:template>
  
  <xd:doc>
    <xd:desc>Template to create parse tree fragments for an non-optional repeat.  It does this by adding its content, and then adding an optional repeat with the same content, as suggested in the iXML spec at https://homepages.cwi.nl/~steven/ixml/ixml-specification.html#L5773.  The resulting fragment is given a unique identifier to avoid infinite recursion and/or failed branches being duplicated.</xd:desc>
  </xd:doc>
  <xsl:template match="repeat1" mode="e:parseTree" as="map(*)">
    <xsl:variable name="GID" select="(@gid, local-name()||generate-id(.))[1]"/>
    <xsl:variable name="equivalent" as="element()*">
      <xsl:sequence select="child::*[not(self::sep)]"/>
    	<alts gid="{$GID}">
    		<alt>
    			<empty/>
    		</alt>
				<alt>
					<xsl:sequence select="sep"/>
					<xsl:copy>
						<xsl:attribute name="gid" select="$GID"/>
						<xsl:copy-of select="@*, node()"/>
					</xsl:copy>
				</alt>
    	</alts>
    </xsl:variable>
  	<xsl:call-template name="e:process-siblings">
  		<xsl:with-param name="siblings" select="$equivalent"/>
  	</xsl:call-template>
  </xsl:template>
  
  <xd:doc>
    <xd:desc>Adds empty terminal rules to the parseTree, adding state references.</xd:desc>
    <xd:param name="visited">The map of visited nonterminals in various states</xd:param>
    <xd:param name="state">The current state reference number.</xd:param>
  	<xd:param name="states">A sequence of strings representing all parsed substrings</xd:param>
  </xd:doc>
  <xsl:template match="empty" mode="e:parseTree" as="map(*)">
    <xsl:param name="visited" tunnel="yes"/>
  	<xsl:param name="states" tunnel="yes"/>
    <xsl:param name="state" as="xs:integer" tunnel="yes"/>
  	<xsl:map>
  		<xsl:map-entry key="'parseTree'">
  			<e:empty state="{$state}"/>
  		</xsl:map-entry>
  		<xsl:map-entry key="'visited'" select="$visited"/>
  		<xsl:map-entry key="'states'" select="$states"/>
  		<xsl:map-entry key="'ends'" select="$state"/>
  	</xsl:map>
  </xsl:template>
	
	<xd:doc>
		<xd:desc>The sep element is not needed in the parse tree (although its children are)</xd:desc>
  </xd:doc>
  <xsl:template match="sep" mode="e:parseTree" as="map(*)">
    <xsl:call-template name="e:process-siblings"/>
  </xsl:template>	
	
	<xd:doc>
		<xd:desc>Ignore text nodes in the grammar tree</xd:desc>
	</xd:doc>
	<xsl:template match="text()" mode="e:parseTree"/>
	
  <!-- Building regex from 'literal', 'inclusion' or 'exclusion' -->
	
	<xsl:mode name="e:charSetRegEx" on-multiple-match="use-last" warning-on-multiple-match="false"/>
   
  <xd:doc>
    <xd:desc>Model inclusion as regex range</xd:desc>
  </xd:doc>
  <xsl:template match="inclusion" mode="e:charSetRegEx" as="xs:string*">
    <xsl:text>[</xsl:text>
    <xsl:apply-templates mode="#current"/>
    <xsl:text>]</xsl:text>
  </xsl:template>
  
  <xd:doc>
    <xd:desc>Model exclusion as regex inverted range</xd:desc>
  </xd:doc>
  <xsl:template match="exclusion" mode="e:charSetRegEx" as="xs:string*">
    <xsl:text>[^</xsl:text>
    <xsl:apply-templates mode="#current"/>
    <xsl:text>]</xsl:text>
  </xsl:template>
  
  <xd:doc>
    <xd:desc>Model ranges</xd:desc>
  </xd:doc>
  <xsl:template match="range" mode="e:charSetRegEx" as="xs:string*">
    <xsl:value-of select="@from"/>
    <xsl:text>-</xsl:text>
    <xsl:value-of select="@to"/>
  </xsl:template>
  
  <xd:doc>
    <xd:desc>Model classes</xd:desc>
  </xd:doc>
  <xsl:template match="class" mode="e:charSetRegEx" as="xs:string*">
    <xsl:text>\p{</xsl:text>
    <xsl:value-of select="@code"/>
    <xsl:text>}</xsl:text>
  </xsl:template>
  
  <xd:doc>
    <xd:desc>Model specific allowed characters in regex</xd:desc>
  </xd:doc>
  <xsl:template match="literal" mode="e:charSetRegEx" as="xs:string*">
  	<xsl:apply-templates select="@*" mode="#current"/>
  </xsl:template>
	
	<xd:doc>
		<xd:desc>By default ignore attribute values (exceptions follow)</xd:desc>
	</xd:doc>
	<xsl:template match="@*" mode="e:charSetRegEx"/>
	
	<xd:doc>
		<xd:desc>Matches strings allowed in double quotes</xd:desc>
	</xd:doc>
	<xsl:template match="@dstring" mode="e:charSetRegEx" as="xs:string*">
		<xsl:value-of select="replace(e:escape-regex(.), '&quot;&quot;', '&quot;', 's')"/>
	</xsl:template>
	
	<xd:doc>
		<xd:desc>Matches strings allowed in single quotes</xd:desc>
	</xd:doc>
	<xsl:template match="@sstring" mode="e:charSetRegEx" as="xs:string*">
		<xsl:value-of select='replace(e:escape-regex(.), "&apos;&apos;", "&apos;", "s")'/>
	</xsl:template>
	
	<xd:doc>
		<xd:desc>Matches strings allowed in hex escapes</xd:desc>
	</xd:doc>
	<xsl:template match="@hex" mode="e:charSetRegEx" as="xs:string*">
		<xsl:value-of select="e:hexToDecimal(.) => codepoints-to-string()"/>
	</xsl:template>
  
  <xd:doc>
    <xd:desc>Copies regular expression granules</xd:desc>
  </xd:doc>
  <xsl:template match="text()" mode="e:charSetRegEx"/>
  
  <!-- pruning the parseTree -->
  
  <xsl:mode name="e:pruneTree" on-no-match="deep-skip"/>
  
  <xd:doc>
    <xd:desc>The containing parseTree parent is not required on output</xd:desc>
  </xd:doc>
  <xsl:template match="e:parseTree" mode="e:pruneTree">
    <xsl:apply-templates mode="#current"/>
  </xsl:template>
  
  <xd:doc>
    <xd:desc>Grammar rules are replaced with their children</xd:desc>
  </xd:doc>
  <xsl:template match="e:rule[not(@mark) and @ends ne '']" mode="e:pruneTree">
    <xsl:variable name="children" as="node()*">
      <xsl:choose>
        <xsl:when test="e:alt">
          <xsl:call-template name="e:process_alts"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates mode="#current"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:if test="$children">
      <xsl:element name="{@name}" exclude-result-prefixes="e" inherit-namespaces="no">
        <xsl:sequence select="$children"/>
      </xsl:element>
    </xsl:if>
  </xsl:template>
  
  <xd:doc>
    <xd:desc>Grammar rules with the '@' mark are captured as attributes</xd:desc>
  </xd:doc>
  <xsl:template match="e:rule[@mark eq '@' and @ends ne '']" mode="e:pruneTree">
    <xsl:where-populated>
      <xsl:attribute name="{@name}">
        <xsl:choose>
          <xsl:when test="e:alt">
            <xsl:call-template name="e:process_alts"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates mode="#current"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
    </xsl:where-populated>
  </xsl:template>
  
  <xd:doc>
    <xd:desc>Grammar rules with the '-' mark are replaced by their content</xd:desc>
  </xd:doc>
  <xsl:template match="e:rule[@mark eq '-' and @ends ne '']" mode="e:pruneTree">
      <xsl:choose>
        <xsl:when test="e:alt">
          <xsl:call-template name="e:process_alts"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates mode="#current"/>
        </xsl:otherwise>
      </xsl:choose>
  </xsl:template>
  
  <xd:doc>
    <xd:desc>This implementation returns the first of any valid alternate parse</xd:desc>
  </xd:doc>
  <xsl:template match="e:alts" name="e:process_alts" mode="e:pruneTree">
    <xsl:variable name="alts" as="element(e:alt)*">
      <xsl:apply-templates mode="#current"/>
    </xsl:variable>
    <xsl:copy-of copy-namespaces="false" select="$alts[1]/(@*, node())"/>
  </xsl:template>
  
  <xd:doc>
    <xd:desc>Adds the content of non-empty alternatives</xd:desc>
  </xd:doc>
  <xsl:template match="e:alt[not(e:fail)]" mode="e:pruneTree"><xsl:variable name="alt" as="node()*">
      <xsl:apply-templates mode="#current"/>
    </xsl:variable>
    <xsl:if test="$alt">
      <xsl:copy copy-namespaces="false">
        <xsl:copy-of select="$alt[self::attribute()]"/>
        <xsl:sequence select="$alt[not(self::attribute())]"/>
      </xsl:copy>
    </xsl:if>
  </xsl:template>
  
  <xd:doc>
    <xd:desc>This key indexes nonterminal rules in particular states using the rule name prepended by the state reference.</xd:desc>
  </xd:doc>
  <xsl:key name="ntByNameState" match="e:rule" use="concat(@state, @name)"/>
	<xsl:key name="ntByNameState" match="e:alts" use="concat(@state, @gid)"/>
  
  <xd:doc>
    <xd:desc>Adds the content of any nonterminal that has already been processed.</xd:desc>
  </xd:doc>
  <xsl:template match="e:nt" mode="e:pruneTree">
    <xsl:apply-templates select="key('ntByNameState', concat(@state, (@gid, @name)[1]))" mode="#current"/>
  </xsl:template>
  
  <xd:doc>
    <xd:desc>Adds the content of literals from the parseTree</xd:desc>
  </xd:doc>
  <xsl:template match="e:literal" mode="e:pruneTree">
    <xsl:value-of select="string(.)"/>
  </xsl:template>
	
	<!-- Named templates -->
	<xd:doc>
		<xd:desc>Processes sibling nodes: this uses iterate as the value of $visited (and others) needs to be passed from preceding to following siblings in document order.</xd:desc>
		<xd:param name="siblings">The population to be iterated over.  Defaults to any sibling children elements of the context node.</xd:param>
	</xd:doc>
	<xsl:template name="e:process-siblings" as="map(*)">
		<xsl:param name="siblings" select="child::*" as="node()*"/>
		<xsl:iterate select="$siblings">
			<xsl:param name="prev.result" select="map{}" as="map(*)"/>
			<xsl:on-completion>
				<xsl:sequence select="$prev.result"/>
			</xsl:on-completion>
			<xsl:choose>
				<xsl:when test="$prev.result?parseTree[self::e:fail]">
					<xsl:break select="$prev.result"/>
				</xsl:when>
				<xsl:otherwise>
					<xsl:next-iteration>
						<xsl:with-param name="prev.result" as="map(*)">
							<xsl:call-template name="e:altStates">
								<xsl:with-param name="prev" select="$prev.result"/>
								<xsl:with-param name="node" select="."/>
							</xsl:call-template>
						</xsl:with-param>
					</xsl:next-iteration>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:iterate>
	</xsl:template>
	
	<xd:doc>
		<xd:desc>Processes sibling alternatives: this uses iterate to pass the values of $visited and $states from one to the other.</xd:desc>
		<xd:param name="sibling-alts">The alternatives to be processed</xd:param>
		<xd:param name="visited">A map detailing which rules and alts have been visited in which states</xd:param>
		<xd:param name="states">A sequence of strings representing the parse.</xd:param>
		<xd:param name="state">The integer representing the current state</xd:param>
	</xd:doc>
	<xsl:template name="e:process-alt-siblings" as="map(*)">
		<xsl:param name="sibling-alts" select="child::alt" as="element(alt)+"/>
		<xsl:param name="visited" as="map(*)" tunnel="yes"/>
		<xsl:param name="states" as="xs:string+" tunnel="yes"/>
		<xsl:param name="state" as="xs:integer" tunnel="yes"/>
		<xsl:iterate select="$sibling-alts">
			<xsl:param name="prev.result" as="map(*)">
				<xsl:map>
					<xsl:map-entry key="'visited'" select="$visited"/>
					<xsl:map-entry key="'states'" select="$states"/>
				</xsl:map>
			</xsl:param>
			<xsl:on-completion>
				<xsl:sequence select="$prev.result"/>
			</xsl:on-completion>
			<xsl:variable name="result" as="map(*)">
				<xsl:apply-templates select="." mode="#current">
					<xsl:with-param name="visited" select="$prev.result?visited" tunnel="yes"/>
					<xsl:with-param name="states" select="$prev.result?states" tunnel="yes"/>
					<xsl:with-param name="state" select="$state" tunnel="yes"/>
				</xsl:apply-templates>
			</xsl:variable>
			<xsl:next-iteration>
				<xsl:with-param name="prev.result" as="map(*)">
					<xsl:map>
						<xsl:map-entry key="'parseTree'" select="$prev.result?parseTree, $result?parseTree"/>
						<xsl:map-entry key="'ends'" select="distinct-values(($prev.result?ends, $result?ends))"/>
						<xsl:sequence select="map:remove($result, ('ends', 'parseTree'))"/>
					</xsl:map>
				</xsl:with-param>
			</xsl:next-iteration>
		</xsl:iterate>
	</xsl:template>
	
	<xd:doc>
		<xd:desc>This template creates an alternative structure around grammar that needs to be processed in a number of different starting states.  It uses iteration rather than for-each because certain metadata needs to be processed in document order, node to node.</xd:desc>
		<xd:param name="prev">metadata from the previous parsed item</xd:param>
		<xd:param name="node">The content to be processed in each state</xd:param>
		<xd:param name="state">The integer representing the current state</xd:param>
		<xd:param name="visited">A map detailing which rules and alts have been visited in which states</xd:param>
		<xd:param name="states">A sequence of strings representing the parse.</xd:param>
	</xd:doc>
	<xsl:template name="e:altStates" as="map(*)">
		<xsl:param name="prev" as="map(*)"/>
		<xsl:param name="node" as="node()"/>
		<xsl:param name="state" as="xs:integer" tunnel="yes"/>
		<xsl:param name="visited" as="map(*)" tunnel="yes"/>
		<xsl:param name="states" as="xs:string+" tunnel="yes"/>
		<xsl:choose>
			<xsl:when test="count($prev?ends) le 1">
				<xsl:variable name="this" as="map(*)">
					<xsl:apply-templates select="$node" mode="#current">
						<xsl:with-param name="state" select="($prev?ends, $state)[1]" tunnel="yes"/>
						<xsl:with-param name="visited" select="($prev?visited, $visited)[1]" tunnel="yes"/>
						<xsl:with-param name="states" select="if (exists($prev?states)) then $prev?states else $states" tunnel="yes"/>
					</xsl:apply-templates>
				</xsl:variable>
				<xsl:map>
					<xsl:map-entry key="'parseTree'">
						<xsl:sequence select="$prev?parseTree, $this?parseTree"/>
					</xsl:map-entry>
					<xsl:map-entry key="'states'" select="$this?states"/>
					<xsl:map-entry key="'ends'" select="$this?ends"/>
					<xsl:map-entry key="'visited'" select="$this?visited"/>
				</xsl:map>
			</xsl:when>
			<xsl:otherwise>
				<xsl:iterate select="$prev?ends">
					<xsl:param name="alt-maps" as="map(*)*"/>					
					<xsl:on-completion>
						<xsl:map>
							<xsl:map-entry key="'parseTree'">
								<xsl:sequence select="$prev?parseTree"/>
								<xsl:where-populated>
									<e:alts>
										<xsl:sequence select="$alt-maps?parseTree"/>
									</e:alts>
								</xsl:where-populated>
							</xsl:map-entry>
							<xsl:map-entry key="'ends'" select="distinct-values($alt-maps?ends)"/>
							<xsl:sequence select="map:remove($alt-maps[last()], ('parseTree', 'ends'))"/>
						</xsl:map>
					</xsl:on-completion>
					<xsl:variable name="this.state" select="." as="xs:integer"/>
					<xsl:variable name="this" as="map(*)">
						<xsl:apply-templates select="$node" mode="#current">
							<xsl:with-param name="state" select="$this.state" tunnel="yes"/>
							<xsl:with-param name="visited" select="if (exists($alt-maps)) then $alt-maps[last()]?visited else $prev?visited" tunnel="yes"/>
							<xsl:with-param name="states" select="if (exists($alt-maps)) then $alt-maps[last()]?states else $prev?states" tunnel="yes"/>
						</xsl:apply-templates>
					</xsl:variable>
					<xsl:next-iteration>
						<xsl:with-param name="alt-maps" as="map(*)*">
							<xsl:sequence select="$alt-maps"/>
							<xsl:map>
								<xsl:map-entry key="'parseTree'">
									<e:alt>
										<xsl:sequence select="$this?parseTree"/>
									</e:alt>
								</xsl:map-entry>
								<xsl:sequence select="map:remove($this, 'parseTree')"/>
							</xsl:map>
						</xsl:with-param>
					</xsl:next-iteration>
				</xsl:iterate>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	
	<!-- General Functions -->
  
  <xd:doc>
    <xd:desc>This performs a custom recursive merge of visited maps</xd:desc>
    <xd:param name="maps">The visited maps to be merged</xd:param>
  </xd:doc>
  <xsl:function name="e:rmerge" as="map(*)">
    <xsl:param name="maps" as="map(*)+"/>
    <xsl:variable name="keys" select="distinct-values(for $map in $maps return map:keys($map))"/>
    <xsl:map>
      <xsl:for-each select="$keys">
        <xsl:variable name="key" select="."/>
        <xsl:variable name="states" select="distinct-values(for $map in $maps[map:contains(., $key)] return map:keys($map($key)))"/>
        <xsl:map-entry key="$key">
          <xsl:map>
            <xsl:for-each select="$states">
              <xsl:variable name="state" select="."/>
            	<xsl:variable name="endStates" as="xs:integer*" select="distinct-values(for $map in $maps[map:contains(., $key)] return $map($key)($state))"/>
              <xsl:map-entry key="$state" select="$endStates"/>
            </xsl:for-each>
          </xsl:map>
        </xsl:map-entry>
      </xsl:for-each>
    </xsl:map>
  </xsl:function>
	
  <xd:doc>
    <xd:desc>This function checks the $visited map for a $key containing a specified $state, and returns true if NOT present.</xd:desc>
    <xd:param name="visited">A map of which keys have been visited in which states</xd:param>
    <xd:param name="key">The name of the nonterminal visited (or not)</xd:param>
    <xd:param name="state">The state reference number in which the visit occured (or not)</xd:param>
  </xd:doc>
  <xsl:function name="e:unvisited" as="xs:boolean">
    <xsl:param name="visited" as="map(*)"/>
    <xsl:param name="key" as="xs:string"/>
    <xsl:param name="state" as="xs:integer"/>
    <xsl:sequence select="not(map:contains($visited, $key) and map:contains($visited($key), string($state)))"/>
  </xsl:function>
  
  <xd:doc>
    <xd:desc>This function returns a new $visited map updated with the new $key, $state and $endState</xd:desc>
    <xd:param name="visited">The map of visited rules and associated states</xd:param>
    <xd:param name="key">The rule name to be updated</xd:param>
    <xd:param name="state">The state to be updated</xd:param>
    <xd:param name="endStates">The end states (if any) to be updated</xd:param>
  </xd:doc>
  <xsl:function name="e:visit" as="map(*)">
    <xsl:param name="visited" as="map(*)"/>
    <xsl:param name="key" as="xs:string"/>
    <xsl:param name="state" as="xs:integer+"/>
    <xsl:param name="endStates" as="xs:integer*"/>
  	<xsl:variable name="existing.ends" as="xs:integer*" select="if (exists($visited($key))) then for $s in $state return $visited($key)($s) else ()"/>
  	<xsl:variable name="local.visited" as="map(*)">
  		<xsl:map>
  			<xsl:map-entry key="$key">
  				<xsl:map>
  					<xsl:for-each select="$state">
  						<xsl:variable name="this.state" select="."/>
  						<xsl:map-entry key="string($this.state)" select="distinct-values(($endStates, $existing.ends))"/>
  					</xsl:for-each>
  				</xsl:map>
  			</xsl:map-entry>
  		</xsl:map>
  	</xsl:variable>
		<xsl:sequence select="e:rmerge(($local.visited, $visited))"/>
  </xsl:function>
  
  <xd:doc>
    <xd:desc>Option for e:visit with implied value for $endState</xd:desc>
    <xd:param name="visited">The map of visited rules and associated states</xd:param>
    <xd:param name="key">The rule name to be updated</xd:param>
    <xd:param name="state">The state to be updated</xd:param>
  </xd:doc>
  <xsl:function name="e:visit" as="map(*)">
    <xsl:param name="visited" as="map(*)"/>
    <xsl:param name="key" as="xs:string"/>
    <xsl:param name="state" as="xs:integer+"/>
    <xsl:sequence select="e:visit($visited, $key, $state, ())"/>
  </xsl:function>
	
	<xd:doc>
		<xd:desc>Converts hexadecimal strings to xs:integer</xd:desc>
		<xd:param name="hexString">The hex string to be used</xd:param>
	</xd:doc>
	<xsl:function name="e:hexToDecimal" as="xs:integer">
		<xsl:param name="hexString"/>
		<xsl:variable name="valueMap" as="map(xs:string, xs:integer)">
			<xsl:map>
				<xsl:iterate select="(0 to 9, 'a', 'b', 'c', 'd', 'e', 'f')">
					<xsl:param name="decValue" select="0" as="xs:integer"/>
					<xsl:map-entry key="string(.)" select="$decValue"/>
					<xsl:next-iteration>
						<xsl:with-param name="decValue" select="$decValue + 1"/>
					</xsl:next-iteration>
				</xsl:iterate>
			</xsl:map>
		</xsl:variable>
		<xsl:variable name="hexSequence" select="$hexString => lower-case() => e:splitString() => reverse()"/>
		<xsl:if test="not($hexSequence = ((0 to 9)!string(), 'a', 'b', 'c', 'd', 'e', 'f'))">
			<xsl:sequence select="error((), $hexString||' is not a hexadecimal value!')"/>
		</xsl:if>
		<xsl:value-of select="sum(for $hex in $hexSequence return $valueMap($hex) * (index-of($hexSequence, $hex)))"/>
	</xsl:function>
	
	<xd:doc>
		<xd:desc>Converts strings into a sequence of characters</xd:desc>
		<xd:param name="string"></xd:param>
	</xd:doc>
	<xsl:function name="e:splitString" as="xs:string*">
		<xsl:param name="string" as="xs:string*"/>
		<xsl:for-each select="$string[not(. eq '')]">
			<xsl:sequence select="substring(., 1, 1), substring(., 2) => e:splitString()"/>
		</xsl:for-each>
	</xsl:function>
	
	<xd:doc>
		<xd:desc>Escapes strings for use as regex strings</xd:desc>
		<xd:param name="string">String value to be escaped</xd:param>
	</xd:doc>
	<xsl:function name="e:escape-regex" as="xs:string?">
		<xsl:param name="string" as="xs:string?"/>
		<xsl:value-of select="replace($string, '(\.|\[|\]|\\|\||\-|\^|\$|\?|\*|\+|\{|\}|\(|\))','\\$1')"/>
	</xsl:function>
  
  <!-- parsing function -->
  
  <xd:doc>
    <xd:desc>This function parses $local.input with the default grammar</xd:desc>
    <xd:param name="local.input">A string to parse with the default grammar</xd:param>
  </xd:doc>
  <xsl:function name="e:parse">
    <xsl:param name="local.input" as="xs:string"/>
    <xsl:sequence select="e:parse-with-grammar($local.input, $grammar)"/>
  </xsl:function>
  
  <xd:doc>
    <xd:desc>This function parses $local.input with a user defined grammar (e.g. where the grammar itself has been generated by a parse operation).</xd:desc>
    <xd:param name="local.input">A string to parse with the $local.grammar grammar</xd:param>
    <xd:param name="local.grammar">An invisible XML grammar as an XML document node.</xd:param>
  </xd:doc>
  <xsl:function name="e:parse-with-grammar">
    <xsl:param name="local.input" as="xs:string"/>
    <xsl:param name="local.grammar" as="document-node(element(ixml))"/>
  	<xsl:variable name="parseTree" as="node()" select="e:parse-tree-with-grammar($local.input, $local.grammar)"/>
    <xsl:variable name="pruneTree" as="node()?">
      <xsl:apply-templates select="$parseTree" mode="e:pruneTree"/>
    </xsl:variable>
		<xsl:sequence select="$pruneTree"/>
  	<xsl:on-empty>
  		<xsl:sequence select="$parseTree"/>
<!--  		<xsl:sequence select="error((), 'No valid parse tree was found', $parseTree)"/>-->
  	</xsl:on-empty>
  </xsl:function>
  
  <xd:doc>
    <xd:desc>This function parses $local.input with a user defined grammar (e.g. where the grammar itself has been generated by a parse operation), and produces a parse tree</xd:desc>
    <xd:param name="local.input">A string to parse with the $local.grammar grammar</xd:param>
    <xd:param name="local.grammar">An invisible XML grammar as an XML document node.</xd:param>
  </xd:doc>
  <xsl:function name="e:parse-tree-with-grammar" cache="true">
    <xsl:param name="local.input" as="xs:string"/>
    <xsl:param name="local.grammar" as="document-node(element(ixml))"/>
      <xsl:apply-templates select="$local.grammar" mode="e:parseTree">
        <xsl:with-param select="$local.input" name="states" tunnel="yes" as="xs:string+"/>
        <xsl:with-param select="$local.grammar" name="grammar" tunnel="yes"/>
      </xsl:apply-templates>
  </xsl:function>
  
  <xd:doc>
    <xd:desc>This function parses $local.input with the default grammar, and produces a parse tree</xd:desc>
    <xd:param name="local.input">A string to parse with the default grammar</xd:param>
  </xd:doc>
  <xsl:function name="e:parse-tree">
    <xsl:param name="local.input" as="xs:string"/>
    <xsl:sequence select="e:parse-tree-with-grammar($local.input, $grammar)"/>
  </xsl:function>
	
</xsl:stylesheet>
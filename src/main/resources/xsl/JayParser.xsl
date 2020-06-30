<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:math="http://www.w3.org/2005/xpath-functions/math"
  xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
  xmlns:e="http://schema.expertml.com/JayParser"
  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
  exclude-result-prefixes="xs math xd map e"
  version="3.0">
  
  <xd:doc scope="stylesheet">
    <xd:desc>
      <xd:p><xd:b>Created on:</xd:b> Jan 16, 2020</xd:p>
      <xd:p><xd:b>Author:</xd:b> Tomos FJ Hillman (TFJH)</xd:p>
      <xd:p>This stylesheet is a proof of concept Earley Parser designed to implement parsing using invisible XML grammars.</xd:p>
    </xd:desc>
  </xd:doc>
  
  <xsl:output indent="yes" method="xml"/>
  
  <xsl:param name="input" as="xs:string" select="'{a=0}'"/>
  <xsl:param name="grammar" as="document-node(element(ixml))" select="document('Program.ixml')"/>
  <xsl:param name="debug" as="xs:boolean" select="false()"/>
  
  <xsl:key name="ruleByName" match="rule" use="@name"/>
  
  <!-- initial templates -->
  
  <xd:doc>
    <xd:desc>Initial templates often don't work as expected...</xd:desc>
  </xd:doc>
  <xsl:template match="/">
    <xsl:call-template name="xsl:initial-template"/>
  </xsl:template>
  
  <xd:doc>
    <xd:desc>This template exists to run the initial POC parse operation</xd:desc>
  </xd:doc>
  <xsl:template name="xsl:initial-template">
    <xsl:sequence select="e:parse($input)"/>
  </xsl:template>
    
  <!-- e:parseTree mode (used for building the parse tree) -->
  
  <xsl:mode name="e:parseTree" on-no-match="shallow-copy"/>
  
  <xd:doc>
    <xd:desc>ixml match template</xd:desc>
  </xd:doc>
  <xsl:template match="ixml" mode="e:parseTree">
    <xsl:apply-templates select="rule[1]" mode="#current">
      <xsl:with-param name="visited" select="map{rule[1]/@name : map{1: ()}}" tunnel="yes"/>
      <xsl:with-param name="state" select="1" tunnel="yes"/>
    </xsl:apply-templates>
  </xsl:template>
  
  <xd:doc>
    <xd:desc>rule match template</xd:desc>
    <xd:param name="state"/>
    <xd:param name="visited"/>
  </xd:doc>
  <xsl:template match="rule" mode="e:parseTree">
    <xsl:param name="state" tunnel="yes" as="xs:integer"/>
    <xsl:param name="visited" tunnel="yes"/>
    <xsl:variable name="children">
      <xsl:call-template name="e:process_children"/>
    </xsl:variable>
    <e:rule>
      <xsl:attribute name="state" select="$state"/>
      <xsl:attribute name="ends" select="$children/*/@ends ! tokenize(., '\s') => distinct-values() => string-join(' ')"/>
      <xsl:apply-templates select="@*" mode="#current"/>
      <xsl:if test="$debug">
        <xsl:comment>visited: <xsl:value-of select="serialize($visited, map{'method':'json', 'indent':true()})"/></xsl:comment>
      </xsl:if>
      <xsl:sequence select="$children"/>
    </e:rule>
  </xsl:template>
  
  <xd:doc>
    <xd:desc/>
  </xd:doc>
  <xsl:template match="sep" mode="e:parseTree">
    <xsl:call-template name="e:process_children">
      <xsl:with-param name="children" select="*"/>
    </xsl:call-template>
  </xsl:template>
  
  <xd:doc>
    <xd:desc/>
    <xd:param name="state"/>
    <xd:param name="visited"/>
  </xd:doc>
  <xsl:template match="alts" mode="e:parseTree">
    <xsl:param name="state" tunnel="yes" as="xs:integer"/>
    <xsl:param name="visited" tunnel="yes"/>
    <xsl:variable name="this.state" select="if (@state) then tokenize(@state, ' ') ! xs:integer(.) else $state"/>
    <xsl:variable name="children" as="item()*">
      <xsl:if test="some $s in $this.state satisfies e:unvisited($visited, (@gid, generate-id(.))[1], $s)">
        <xsl:call-template name="e:process_children">
          <xsl:with-param name="visited" select="e:visit($visited, (@gid, generate-id(.))[1], $this.state)" tunnel="yes"/>
        </xsl:call-template>
      </xsl:if>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="$children">
        <e:alts state="{$this.state}">
          <xsl:if test="$children/*/@ends">
            <xsl:attribute name="ends" select="$children/*/@ends ! tokenize(., '\s') => distinct-values() => string-join(' ')"/>
          </xsl:if>
          <xsl:apply-templates select="@gid" mode="#current"/>
          <xsl:if test="$debug">
            <xsl:comment>visited in state <xsl:value-of select="$state"/>: <xsl:value-of select="serialize($visited, map{'method':'json', 'indent':true()})"/></xsl:comment>
          </xsl:if>
          <xsl:sequence select="$children"/>
        </e:alts>
      </xsl:when>
      <xsl:otherwise>
        <e:empty state="{$this.state}" ends="{$this.state}"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xd:doc>
    <xd:desc/>
    <xd:param name="state"/>
    <xd:param name="states"/>
  </xd:doc>
  <xsl:template match="alt" mode="e:parseTree">
    <xsl:param name="state" tunnel="yes" as="xs:integer"/>
    <xsl:param name="states" tunnel="yes"/>
    <xsl:variable name="this.state" select="(@state, $state)[1]"/>
    <xsl:variable name="children">
      <xsl:call-template name="e:process_children">
        <xsl:with-param tunnel="yes" name="state" select="$this.state"/>
      </xsl:call-template>
    </xsl:variable>
    <e:alt state="{$this.state}">
      <xsl:variable name="remaining" select="($children/*/@remaining)[last()]" as="xs:string?"/>
      <xsl:choose>
        <xsl:when test="$remaining">
          <xsl:variable name="new.states" select="($states, $remaining[not($remaining = $states)])"/>
          <xsl:attribute name="ends" select="(string(index-of($new.states, $remaining)), $children/*/@ends)[last()] ! tokenize(., '\s') => distinct-values() => string-join(' ')"/>
        </xsl:when>
        <xsl:when test="$children/*/@ends[. ne ''] and not($children/*[self::e:fail])">
          <xsl:attribute name="ends" select="($children/*/@ends[. ne ''])[last()] ! tokenize(., '\s') => distinct-values() => string-join(' ')"/>
        </xsl:when>
      </xsl:choose>
      <xsl:sequence select="$children"/>
    </e:alt>
  </xsl:template>
  
  <xd:doc>
    <xd:desc/>
    <xd:param name="grammar"/>
    <xd:param name="state"/>
    <xd:param name="visited"/>
  </xd:doc>
  <xsl:template match="nonterminal" mode="e:parseTree">
    <xsl:param name="grammar" tunnel="yes"/>
    <xsl:param name="state" tunnel="yes" as="xs:integer"/>
    <xsl:param name="visited" tunnel="yes" as="map(*)"/>
    <xsl:variable name="unvisited" as="xs:boolean" select="e:unvisited($visited, @name, $state)"/>
    <xsl:if test="$debug">
      <xsl:comment><xsl:value-of select="serialize($visited, map{'method':'json', 'indent':true()})"/></xsl:comment>
      <xsl:comment>Matching <xsl:value-of select="if ($unvisited) then 'UN' else ''"/>VISITED nonterminal "<xsl:value-of select="@name"/>" in state <xsl:value-of select="$state"/></xsl:comment>
    </xsl:if>
    <xsl:choose>
      <xsl:when test="$unvisited">
        <xsl:apply-templates select="key('ruleByName', @name, $grammar)" mode="#current">
          <xsl:with-param name="visited" tunnel="yes" select="e:visit($visited, @name, $state)"/>
        </xsl:apply-templates>
      </xsl:when>
      <xsl:when test="not($visited(@name)(string($state)))">
        <e:fail state="{$state}" nt="{@name}"/>
      </xsl:when>
      <xsl:otherwise>
        <e:nt state="{$state}" ends="{$visited(@name)(string($state))}">
          <xsl:copy-of select="@name"/>
        </e:nt>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xd:doc>
    <xd:desc/>
    
    <xd:param name="state"/>
    
    <xd:param name="states"/>
  </xd:doc>
  <xsl:template match="literal[@dstring]" mode="e:parseTree">
    <xsl:param name="states" as="xs:string+" tunnel="yes"/>    
    <xsl:param name="state" as="xs:integer" tunnel="yes"/>
    <xsl:variable name="match" as="xs:boolean" select="starts-with($states[$state], @dstring)"/>
    <xsl:choose>
      <xsl:when test="$match">
        <xsl:variable name="remaining" select="substring-after($states[$state], @dstring)"/>
        <xsl:variable name="altered.states" select="($states, $remaining[not(. = $states)])"/>
        <xsl:variable name="ends" select="index-of($altered.states, $remaining)" as="xs:integer*"/>
        <e:literal state="{$state}" ends="{if ($remaining eq '') then 0 else string-join($ends, ' ')}">
          <xsl:attribute name="remaining" select="$remaining"/>
          <xsl:value-of select="@dstring"/>
        </e:literal>
      </xsl:when>
      <xsl:otherwise>
        <e:fail state="{$state}" string="{@dstring}"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xd:doc>
    <xd:desc/>
    <xd:param name="state"/>
    <xd:param name="states"/>
  </xd:doc>
  <xsl:template match="inclusion|exclusion" mode="e:parseTree">
    <xsl:param name="states" as="xs:string+" tunnel="yes"/>    
    <xsl:param name="state" as="xs:integer" tunnel="yes"/>
    <xsl:variable name="regex" as="xs:string">
      <xsl:variable name="seq">
        <xsl:text>^(</xsl:text>
        <xsl:apply-templates select="." mode="e:charSetRegEx"/>
        <xsl:text>).*?$</xsl:text>
      </xsl:variable>
      <xsl:sequence select="string-join($seq)"/>
    </xsl:variable>
    <xsl:variable name="match" as="xs:boolean" select="matches($states[$state], $regex)"/>
    <xsl:choose>
      <xsl:when test="$match">
        <xsl:variable name="matched" as="xs:string" select="replace($states[$state], $regex, '$1')"/>
        <xsl:variable name="remaining" select="substring-after($states[$state], $matched)"/>
        <xsl:variable name="altered.states" select="($states, $remaining[not(. = $states)])"/>
        <xsl:variable name="ends" select="index-of($altered.states, $remaining)" as="xs:integer*"/>
        <e:literal state="{$state}" ends="{if ($remaining eq '') then 0 else string-join($ends, ' ')}">
            <xsl:attribute name="remaining" select="$remaining"/>      
          <xsl:value-of select="$matched"/>
        </e:literal>
      </xsl:when>
      <xsl:otherwise>
        <e:fail state="{$state}" regex="{$regex}"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xd:doc>
    <xd:desc/>
    <xd:param name="visited"/>
    <xd:param name="state"/>
  </xd:doc>
  <xsl:template match="repeat0" mode="e:parseTree">
    <xsl:param name="visited" tunnel="yes"/>
    <xsl:param name="state" tunnel="yes"/>
    <xsl:variable name="GID" select="(@gid, generate-id(.))[1]"/>
    <xsl:variable name="equivalent" as="element(alts)">
      <alts gid="{$GID}">
        <alt>
          <empty/>
        </alt>
        <alt>
          <xsl:sequence select="(child::*[not(self::sep)], sep)"/>
          <xsl:copy>
            <xsl:attribute name="gid" select="$GID"/>
            <xsl:copy-of select="@*, node()"/>
          </xsl:copy>
        </alt>
      </alts>
    </xsl:variable>
    <xsl:if test="e:unvisited($visited, $GID, $state)">
      <xsl:call-template name="e:process_children">
        <xsl:with-param name="children" select="$equivalent"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>
  
  <xd:doc>
    <xd:desc></xd:desc>
  </xd:doc>
  <xsl:template match="option" mode="e:parseTree">
    <xsl:variable name="GID" select="(@gid, generate-id(.))[1]"/>
    <xsl:call-template name="e:process_children">
      <xsl:with-param name="children">
        <alts gid="$GID">
          <alt>
            <empty/>
          </alt>
          <alt>
            <xsl:sequence select="child::*"/>
          </alt>
        </alts>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  
  <xd:doc>
    <xd:desc/>
    
    <xd:param name="state"/>
  </xd:doc>
  <xsl:template match="repeat1" mode="e:parseTree">
    <xsl:param name="state" tunnel="yes"/>
    <xsl:variable name="equivalent" as="element()*">
      <xsl:sequence select="(child::*[not(self::sep)], sep)"/>
      <repeat0 gid="{generate-id(.)}">
        <xsl:sequence select="*"/>
      </repeat0>
    </xsl:variable>
    <xsl:call-template name="e:process_children">
      <xsl:with-param name="children" select="$equivalent"/>
    </xsl:call-template>
  </xsl:template>
  
  <xd:doc>
    <xd:desc/>
    <xd:param name="visited"/>
    <xd:param name="state"/>
  </xd:doc>
  <xsl:template match="empty" mode="e:parseTree">
    <xsl:param name="visited" tunnel="yes"/>
    <xsl:param name="state" as="xs:integer" tunnel="yes"/>
    <e:empty>
      <xsl:attribute name="state" select="$state"/>
    </e:empty>
  </xsl:template>
  
  <xd:doc>
    <xd:desc>process sibling called template</xd:desc>
    <xd:param name="children"/>
    <xd:param name="state"/>
    
    <xd:param name="visited"/>
    <xd:param name="states"/>
  </xd:doc>
  <xsl:template name="e:process_children">
    <xsl:param name="states" as="xs:string+" tunnel="yes"/>  
    <xsl:param name="children" select="child::*" as="node()*"/>
    <xsl:param name="state" tunnel="yes" as="xs:integer"/>
    <xsl:param name="visited" tunnel="yes"/>
    <xsl:variable name="first" as="node()*">
      <xsl:apply-templates select="head($children)" mode="#current"/>
    </xsl:variable>
    <xsl:sequence select="$first"/>
    <xsl:if test="not($first[self::e:fail]) and tail($children)">
      <xsl:variable name="new.states" select="e:getStates($states, $first)" as="xs:string+"/>
      <xsl:variable name="new.state" as="xs:integer+">
        <xsl:choose>
          <xsl:when test="$first[self::e:alt]">
            <xsl:sequence select="$state"/>
          </xsl:when>
          <xsl:when test="$first/@ends[. ne '']">
            <xsl:sequence select="distinct-values($first/@ends ! tokenize(., ' ')) ! xs:integer(.)"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:sequence select="$state"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <xsl:choose>
        <xsl:when test="count($new.state) gt 1">
          <xsl:variable name="equivalent" as="element(alts)">
            <alts state="{$new.state}">
              <xsl:for-each select="$new.state">
                <alt state="{.}">
                  <xsl:sequence select="tail($children)"/>
                </alt>
              </xsl:for-each>
            </alts>
          </xsl:variable>
          <xsl:call-template name="e:process_children">
            <xsl:with-param name="children" select="$equivalent"/>
            <xsl:with-param name="visited" tunnel="yes" select="e:getVisited($visited, $first)"/>
            <xsl:with-param name="states" tunnel="yes" select="$new.states"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="e:process_children">
            <xsl:with-param name="children" select="tail($children)"/>
            <xsl:with-param name="visited" tunnel="yes" select="e:getVisited($visited, $first)"/>
            <xsl:with-param name="state" tunnel="yes" select="$new.state[last()]" as="xs:integer"/>
            <xsl:with-param name="states" tunnel="yes" select="$new.states"/>
          </xsl:call-template>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:if>
  </xsl:template>
  
  <!-- Building regex from 'inclusion' or 'exclusion' -->
   
  <xd:doc>
    <xd:desc>Model inclusion as regex range</xd:desc>
  </xd:doc>
  <xsl:template match="inclusion" mode="e:charSetRegEx">
    <xsl:text>[</xsl:text>
    <xsl:apply-templates mode="#current"/>
    <xsl:text>]</xsl:text>
  </xsl:template>
  
  <xd:doc>
    <xd:desc>Model exclusion as regex inverted range</xd:desc>
  </xd:doc>
  <xsl:template match="exclusion" mode="e:charSetRegEx">
    <xsl:text>[^</xsl:text>
    <xsl:apply-templates mode="#current"/>
    <xsl:text>]</xsl:text>
  </xsl:template>
  
  <xd:doc>
    <xd:desc>Model ranges</xd:desc>
  </xd:doc>
  <xsl:template match="range" mode="e:charSetRegEx">
    <xsl:value-of select="@from"/>
    <xsl:text>-</xsl:text>
    <xsl:value-of select="@to"/>
  </xsl:template>
  
  <xd:doc>
    <xd:desc/>
  </xd:doc>
  <xsl:template match="text()" mode="e:charSetRegEx"/>
  
  <!-- determining new states sequences: this somewhat depends on nodes being returned in document order! -->
  
  <xsl:mode name="e:states" on-no-match="shallow-skip"/>
  
  <xd:doc>
    <xd:desc/>
    <xd:param name="states"/>
  </xd:doc>
  <xsl:template match="*[@remaining ne '']" mode="e:states">
    <xsl:param tunnel="yes" name="states"/>
    <xsl:if test="not(@remaining = $states)">
      <xsl:sequence select="string(@remaining)"/>
    </xsl:if>
  </xsl:template>
  
  <xd:doc>
    <xd:desc/>
    <xd:param name="states"/>
    <xd:param name="nodes"/>
  </xd:doc>
  <xsl:function name="e:getStates" as="xs:string+">
    <xsl:param name="states" as="xs:string+"/>
    <xsl:param name="nodes" as="node()+"/>
    <xsl:sequence select="$states"/>
    <xsl:apply-templates select="$nodes" mode="e:states">
      <xsl:with-param name="states" select="$states" tunnel="yes"/>
    </xsl:apply-templates>
  </xsl:function>
  
  <!-- determining new visited maps: this depends on nodes being returned in sequence also... -->
  
  <xsl:mode name="e:visited" on-no-match="shallow-skip"/>
  
  <xd:doc>
    <xd:desc/>
    <xd:param name="visited"/>
  </xd:doc>
  <xsl:template match="e:rule" mode="e:visited">
    <xsl:param name="visited" tunnel="yes" as="map(*)"/>
    <xsl:variable name="ends" select="tokenize(@ends, ' ') ! xs:integer(.)"/>
    <xsl:apply-templates mode="#current">
      <xsl:with-param name="visited" tunnel="yes" select="e:visit($visited, @name, @state, $ends)"/>
    </xsl:apply-templates>
  </xsl:template>
  
  <xd:doc>
    <xd:desc/>
    <xd:param name="visited"/>
  </xd:doc>
  <xsl:template match="e:alts[@gid]" mode="e:visited">
    <xsl:param name="visited" tunnel="yes" as="map(*)"/>
    <xsl:variable name="ends" select="tokenize(@ends, ' ') ! xs:integer(.)"/>
    <xsl:apply-templates mode="#current">
      <xsl:with-param name="visited" tunnel="yes" select="e:visit($visited, @gid, @state, $ends)"/>
    </xsl:apply-templates>
  </xsl:template>
  
  <xd:doc>
    <xd:desc/>
    <xd:param name="visited"/>
  </xd:doc>
  <xsl:template match="e:fail|e:empty|e:literal" mode="e:visited">
    <xsl:param name="visited" tunnel="yes"/>
    <xsl:sequence select="$visited"/>
  </xsl:template>
  
  <xd:doc>
    <xd:desc/>
    <xd:param name="visited"/>
    <xd:param name="nodes"/>
  </xd:doc>
  <xsl:function name="e:getVisited" as="map(*)">
    <xsl:param name="visited" as="map(*)"/>
    <xsl:param name="nodes" as="node()+"/>
    <xsl:variable name="newMap" as="map(*)*">
      <xsl:apply-templates select="$nodes" mode="e:visited">
        <xsl:with-param name="visited" tunnel="yes" select="$visited"/>
      </xsl:apply-templates>
    </xsl:variable>
    <xsl:sequence select="e:rmerge(($visited, $newMap))"/>
  </xsl:function>
  
  <xd:doc>
    <xd:desc>This function checks the $visited map for a $key containing a specified $state, and returns true if NOT present.</xd:desc>
    <xd:param name="visited">A map of which keys have been visited in which states</xd:param>
    <xd:param name="key"/>
    <xd:param name="state"/>
  </xd:doc>
  <xsl:function name="e:unvisited" as="xs:boolean">
    <xsl:param name="visited" as="map(*)"/>
    <xsl:param name="key" as="xs:string"/>
    <xsl:param name="state" as="xs:integer"/>
    <xsl:sequence select="not(map:contains($visited, $key) and map:contains($visited($key), string($state)))"/>
  </xsl:function>
  
  <xd:doc>
    <xd:desc/>
    <xd:param name="maps"/>
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
              <xsl:variable name="raw.endStates" as="xs:string*" select="
                  for $map in $maps[map:contains(., $key)]
                  return
                    $map($key)($state)"/>
              <xsl:variable name="distinct.endStates" as="xs:string*" select="
                  distinct-values(for $es in $raw.endStates
                  return
                    tokenize($es, ' '))"/>
              <xsl:variable name="endStates" as="xs:string" select="string-join($distinct.endStates, ' ')"/>
              <xsl:map-entry key="$state" select="$endStates"/>
            </xsl:for-each>
          </xsl:map>
        </xsl:map-entry>
      </xsl:for-each>
    </xsl:map>
  </xsl:function>
  
  <xd:doc>
    <xd:desc>This function returns a new $visited map updated with the new $key, $state and $endState</xd:desc>
    <xd:param name="visited"/>
    <xd:param name="key"/>
    <xd:param name="state"/>
    <xd:param name="endStates"/>
  </xd:doc>
  <xsl:function name="e:visit" as="map(*)">
    <xsl:param name="visited" as="map(*)"/>
    <xsl:param name="key" as="xs:string"/>
    <xsl:param name="state" as="xs:integer+"/>
    <xsl:param name="endStates" as="xs:integer*"/>    
    <xsl:variable name="allStates" as="map(*)*" select="map:merge((for $s in $state return map{string($s): string-join($endStates, ' ')}, $visited($key)) )"/>
    <xsl:sequence select="map:merge( (map{$key : $allStates}, $visited) )"/>
  </xsl:function>
  
  <xd:doc>
    <xd:desc>Option for e:visit with implied value for $endState</xd:desc>
    <xd:param name="visited"/>
    <xd:param name="key"/>
    <xd:param name="state"/>
  </xd:doc>
  <xsl:function name="e:visit" as="map(*)">
    <xsl:param name="visited" as="map(*)"/>
    <xsl:param name="key" as="xs:string"/>
    <xsl:param name="state" as="xs:integer+"/>
    <xsl:sequence select="e:visit($visited, $key, $state, ())"/>
  </xsl:function>
  
  <!-- pruning the parseTree -->
  
  <xsl:mode name="e:pruneTree" on-no-match="deep-skip"/>
  
  <xd:doc>
    <xd:desc/>
  </xd:doc>
  <xsl:template match="e:parseTree" mode="e:pruneTree">
    <xsl:apply-templates mode="#current"/>
  </xsl:template>
  
  <xd:doc>
    <xd:desc/>
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
        <xsl:if test="$debug">
          <xsl:copy-of select="@state, @ends" copy-namespaces="false"/>
        </xsl:if>
        <xsl:sequence select="$children"/>
      </xsl:element>
    </xsl:if>
  </xsl:template>
  
  <xsl:key name="toKeep" match="e:empty|e:literal" use="ancestor::*!generate-id()"/>
  
  <xd:doc>
    <xd:desc/>
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
    <xd:desc/>
  </xd:doc>
  <xsl:template match="e:alts" name="e:process_alts" mode="e:pruneTree">
    <xsl:variable name="alts" as="element(e:alt)*">
      <xsl:apply-templates mode="#current"/>
    </xsl:variable>
    <xsl:sequence select="$alts[1]/node()"/>
  </xsl:template>
  
  <xd:doc>
    <xd:desc/>
  </xd:doc>
  <xsl:template match="e:alt[not(e:fail)]" mode="e:pruneTree">
    <xsl:variable name="alt" as="node()*">
      <xsl:apply-templates mode="#current"/>
    </xsl:variable>
    <xsl:if test="$alt">
      <xsl:copy copy-namespaces="false">
        <xsl:copy-of select="@*" copy-namespaces="false"/>
        <xsl:sequence select="$alt"/>
      </xsl:copy>
    </xsl:if>
  </xsl:template>
  
  <xsl:key name="ntByNameState" match="e:rule" use="concat(@state, @name)"/>
  
  <xd:doc>
    <xd:desc/>
  </xd:doc>
  <xsl:template match="e:nt" mode="e:pruneTree">
    <xsl:apply-templates select="key('ntByNameState', concat(@state, @name))" mode="#current"/>
  </xsl:template>
  
  <xd:doc>
    <xd:desc/>
  </xd:doc>
  <xsl:template match="e:literal" mode="e:pruneTree">
    <xsl:value-of select="string(.)"/>
  </xsl:template>
  
  <!-- parsing function -->
  
  <xd:doc>
    <xd:desc>This function parses $local.input with the default grammar</xd:desc>
    <xd:param name="local.input"/>
  </xd:doc>
  <xsl:function name="e:parse">
    <xsl:param name="local.input" as="xs:string"/>
    <xsl:sequence select="e:parse-with-grammar($local.input, $grammar)"/>
  </xsl:function>
  
  <xd:doc>
    <xd:desc>This function parses $local.input with a user defined grammar (e.g. where the grammar itself has been generated by a parse operation).</xd:desc>
    <xd:param name="local.input"/>
    <xd:param name="local.grammar"/>
  </xd:doc>
  <xsl:function name="e:parse-with-grammar">
    <xsl:param name="local.input" as="xs:string"/>
    <xsl:param name="local.grammar" as="document-node(element(ixml))"/>
    <xsl:variable name="parseTree">
      <xsl:apply-templates select="$local.grammar" mode="e:parseTree">
        <xsl:with-param select="$local.input" name="states" tunnel="yes" as="xs:string+"/>
        <xsl:with-param select="$local.grammar" name="grammar" tunnel="yes"/>
      </xsl:apply-templates>
    </xsl:variable>
    <xsl:variable name="pruneTree">
      <xsl:apply-templates select="$parseTree" mode="e:pruneTree">
        <xsl:with-param name="parseTree" tunnel="yes" select="$parseTree"/>
      </xsl:apply-templates>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="$debug or count($pruneTree) gt 1">
        <e:parse>
          <xsl:if test="$debug">
            <xsl:sequence select="$parseTree"/>
          </xsl:if>
          <xsl:sequence select="$pruneTree"/>
        </e:parse>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="$pruneTree"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>
  
</xsl:stylesheet>
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:template match="/">
<html>
<body style="font-family:Arial,helvetica,sans-serif;">
<xsl:apply-templates/> 
<hr />
trailer
</body>
</html>
</xsl:template>

<xsl:template match="file/entry">
<p><xsl:value-of select="@no"/>:<br />
<xsl:apply-templates/>
</p>
</xsl:template>

<xsl:template match="variant">
<xsl:value-of select="@no"/> (<xsl:value-of select="@confidence"/>):
<xsl:apply-templates/><br />
</xsl:template>

<xsl:template match="author">
<span style="color:red"><xsl:apply-templates/></span>
</xsl:template>
<xsl:template match="booktitle">
<span style="color:orange"><xsl:apply-templates/></span>
</xsl:template>
<xsl:template match="date">
<span style="color:gold"><xsl:apply-templates/></span>
</xsl:template>
<xsl:template match="editor">
<span style="color:navy"><xsl:apply-templates/></span>
</xsl:template>
<xsl:template match="institution">
<span style="color:purple"><xsl:apply-templates/></span>
</xsl:template>
<xsl:template match="journal">
<span style="color:green; font-style:italic"><xsl:apply-templates/></span>
</xsl:template>
<xsl:template match="location">
<span style="color:blue"><xsl:apply-templates/></span>
</xsl:template>
<xsl:template match="note">
<span style="color:tan"><xsl:apply-templates/></span>
</xsl:template>
<xsl:template match="pages">
<span style="color:darkgray"><xsl:apply-templates/></span>
</xsl:template>
<xsl:template match="publisher">
<span style="color:green"><xsl:apply-templates/></span>
</xsl:template>
<xsl:template match="tech">
<span style="color:aqua"><xsl:apply-templates/></span>
</xsl:template>
<xsl:template match="title">
<span style="color:blue; font-weight:bold"><xsl:apply-templates/></span>
</xsl:template>
<xsl:template match="volume">
<span style="color:salmon"><xsl:apply-templates/></span>
</xsl:template>


<xsl:template match="error">
<xsl:choose>
  <xsl:when test="@correct='author'">
    <span title="author" style="background:pink"><xsl:apply-templates/></span>
  </xsl:when>
  <xsl:when test="@correct='booktitle'">
    <span title="booktitle" style="background:pink"><xsl:apply-templates/></span>
  </xsl:when>
  <xsl:when test="@correct='date'">
    <span title="date" style="background:pink"><xsl:apply-templates/></span>
  </xsl:when>
  <xsl:when test="@correct='editor'">
    <span title="editor" style="background:pink"><xsl:apply-templates/></span>
  </xsl:when>
  <xsl:when test="@correct='institution'">
    <span title="institution" style="background:pink"><xsl:apply-templates/></span>
  </xsl:when>
  <xsl:when test="@correct='journal'">
    <span title="journal" style="background:pink"><xsl:apply-templates/></span>
  </xsl:when>
  <xsl:when test="@correct='location'">
    <span title="location" style="background:pink"><xsl:apply-templates/></span>
  </xsl:when>
  <xsl:when test="@correct='note'">
    <span title="note" style="background:pink"><xsl:apply-templates/></span>
  </xsl:when>
  <xsl:when test="@correct='pages'">
    <span title="pages" style="background:pink"><xsl:apply-templates/></span>
  </xsl:when>
  <xsl:when test="@correct='publisher'">
    <span title="publisher" style="background:pink"><xsl:apply-templates/></span>
  </xsl:when>
  <xsl:when test="@correct='tech'">
    <span title="tech" style="background:pink"><xsl:apply-templates/></span>
  </xsl:when>
  <xsl:when test="@correct='title'">
    <span title="title" style="background:pink"><xsl:apply-templates/></span>
  </xsl:when>
  <xsl:when test="@correct='volume'">
    <span title="volume" style="background:pink"><xsl:apply-templates/></span>
  </xsl:when>
  <xsl:otherwise>
    <span title="ha" style="background:pink"><xsl:apply-templates/></span>
  </xsl:otherwise>
</xsl:choose>
</xsl:template>

</xsl:stylesheet>

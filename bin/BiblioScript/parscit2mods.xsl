<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0" xmlns:mods="http://www.loc.gov/mods/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-2.xsd"
    xmlns:xd="http://www.pnp-software.com/XSLTdoc">
    <xd:author>Matteo Romanello</xd:author>
    <xsl:output method="xml" indent="yes"/>
    <xsl:template match="citationList">
        <xsl:element name="modsCollection" namespace="http://www.loc.gov/mods/v3">
            <xsl:attribute name="xsi:schemaLocation" namespace="http://www.w3.org/2001/XMLSchema-instance">http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-2.xsd</xsl:attribute>
            <xsl:comment> ### JOURNAL ARTICLES ### </xsl:comment>
            <xsl:apply-templates select="citation[journal]"/>
            <xsl:comment> ### BOOKS ### </xsl:comment>
            <xsl:apply-templates select="citation[title and not(booktitle) and not(pages) and not(journal)]"/>
            <xsl:comment> ### BOOK SECTIONS ### </xsl:comment>
            <xsl:apply-templates select="citation[title and booktitle and not(journal)]"/>
        </xsl:element>
    </xsl:template>
    <xd:doc> Here is where most of the inetersting stuff happen. </xd:doc>
    <xsl:template match="citation">
        <xsl:element name="mods" namespace="http://www.loc.gov/mods/v3">
            <xsl:attribute name="ID">
                <!-- add compatibility check for saxon or not -->
                <xsl:value-of select="generate-id()"/>
            </xsl:attribute>
            <xsl:apply-templates select="title"/>
            <xsl:element name="typeOfResource" namespace="http://www.loc.gov/mods/v3">text</xsl:element>
            <!-- heuristic to determine the kind of resource -->
            <xsl:choose>
                <!-- CASE 1: Paper in a Journal-->
                <xsl:when test="./journal">
                    <xsl:apply-templates select="authors" mode="journal_article"/>
                    <xsl:element name="relatedItem" namespace="http://www.loc.gov/mods/v3">
                        <xsl:attribute name="type">host</xsl:attribute>
                        <xsl:apply-templates select="journal" mode="journal_article"/>
                        <xsl:element name="originInfo" namespace="http://www.loc.gov/mods/v3">
                            <xsl:element name="issuance" namespace="http://www.loc.gov/mods/v3">continuing</xsl:element>
                        </xsl:element>
                        <xsl:apply-templates select="pages" mode="all"/>
                        <xsl:element name="genre" namespace="http://www.loc.gov/mods/v3">
                            <xsl:attribute name="authority">marc</xsl:attribute>
                            <xsl:text>journal</xsl:text>
                        </xsl:element>
                        <xsl:element name="genre" namespace="http://www.loc.gov/mods/v3">
                            <xsl:text>academic journal</xsl:text>
                        </xsl:element>

                    </xsl:element>
                </xsl:when>
                <!-- CASE 2: Book -->
                <xsl:when test=".[title and not(booktitle) and not(pages) and not(journal)]">
                    <xsl:apply-templates select="authors" mode="book"/>
                    <xsl:element name="originInfo" namespace="http://www.loc.gov/mods/v3">
                        <xsl:apply-templates select="location | date | publisher" mode="book"/>
                        <xsl:element name="issuance" namespace="http://www.loc.gov/mods/v3">monographic</xsl:element>
                        <xsl:apply-templates select="pages" mode="all"/>
                    </xsl:element>
                </xsl:when>
                <!-- CASE 3: Book Section -->
                <xsl:otherwise>
                    <xsl:apply-templates select="authors" mode="book_section"/>
                    <xsl:element name="relatedItem" namespace="http://www.loc.gov/mods/v3">
                        <xsl:attribute name="type">host</xsl:attribute>
                        <xsl:apply-templates select="pages | booktitle" mode="all"/>
                        <xsl:apply-templates select="editor">
                            <xsl:with-param name="mode">book_editor</xsl:with-param>
                        </xsl:apply-templates>
                        <xsl:element name="originInfo" namespace="http://www.loc.gov/mods/v3">
                            <xsl:element name="issuance" namespace="http://www.loc.gov/mods/v3">monographic</xsl:element>
                            <xsl:apply-templates select="location | date | publisher" mode="book"/>
                        </xsl:element>
                        <xsl:element name="genre" namespace="http://www.loc.gov/mods/v3">collection</xsl:element>
                    </xsl:element>
                </xsl:otherwise>
            </xsl:choose>
            <xsl:element name="identifier" namespace="http://www.loc.gov/mods/v3">
                <xsl:attribute name="type">citekey</xsl:attribute>
                <xsl:value-of select="generate-id()"/>
            </xsl:element>
        </xsl:element>
    </xsl:template>
    <xd:doc>Auhtors of a journal article</xd:doc>
    <xsl:template match="authors" mode="journal_article">
        <xsl:apply-templates select="author">
            <xsl:with-param name="mode">journal_article</xsl:with-param>
        </xsl:apply-templates>
    </xsl:template>
    <xd:doc>Auhtors of a book</xd:doc>
    <xsl:template match="authors" mode="book">
        <xsl:apply-templates select="author">
            <xsl:with-param name="mode">book</xsl:with-param>
        </xsl:apply-templates>
    </xsl:template>
    <xsl:template match="authors" mode="book_section">
        <xsl:apply-templates select="author">
            <xsl:with-param name="mode">book_section</xsl:with-param>
        </xsl:apply-templates>
    </xsl:template>
    <xd:doc>Handles the creation of name elements in mods format. <xd:param type="string">The current mode.</xd:param>
    </xd:doc>
    <xsl:template match="author|editor">
        <xsl:param name="mode"/>
        <xsl:element name="name" namespace="http://www.loc.gov/mods/v3">
            <xsl:attribute name="type">personal</xsl:attribute>
            <xsl:for-each select="tokenize(.,' ')">
                <xsl:element name="namePart" namespace="http://www.loc.gov/mods/v3">
                    <xsl:choose>
                        <xsl:when test="string-length(.)=1">
                            <xsl:attribute name="type">given</xsl:attribute>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:attribute name="type">family</xsl:attribute>
                        </xsl:otherwise>
                    </xsl:choose>
                    <xsl:value-of select="."/>
                </xsl:element>
            </xsl:for-each>
            <xsl:element name="role" namespace="http://www.loc.gov/mods/v3">
                <xsl:element name="roleTerm" namespace="http://www.loc.gov/mods/v3">
                    <xsl:attribute name="authority">marcrelator</xsl:attribute>
                    <xsl:attribute name="type">text</xsl:attribute>
                    <xsl:choose>
                        <xsl:when test="$mode='journal_article'">
                            <xsl:text>author</xsl:text>
                        </xsl:when>
                        <xsl:when test="$mode='book'">
                            <xsl:text>creator</xsl:text>
                        </xsl:when>
                        <xsl:when test="$mode='book_section'">
                            <xsl:text>author</xsl:text>
                        </xsl:when>
                        <xsl:when test="$mode='book_editor'">
                            <xsl:text>editor</xsl:text>
                        </xsl:when>
                    </xsl:choose>
                </xsl:element>
            </xsl:element>
        </xsl:element>
    </xsl:template>
    <xsl:template name="title">
        <xsl:element name="titleInfo" namespace="http://www.loc.gov/mods/v3">
            <xsl:element name="title" namespace="http://www.loc.gov/mods/v3">
                <xsl:value-of select="."/>
            </xsl:element>
        </xsl:element>
    </xsl:template>
    <xsl:template match="title">
        <xsl:call-template name="title"/>
    </xsl:template>
    <xsl:template match="journal" mode="journal_article">
        <xsl:call-template name="title"/>
    </xsl:template>
    <xsl:template match="pages" mode="all">
        <xsl:element name="part" namespace="http://www.loc.gov/mods/v3">
            <xsl:element name="extent" namespace="http://www.loc.gov/mods/v3">
                <xsl:attribute name="unit">page</xsl:attribute>
                <xsl:element name="start" namespace="http://www.loc.gov/mods/v3">
                    <xsl:value-of select="tokenize(.,'--')[1]"/>
                </xsl:element>
                <xsl:element name="end" namespace="http://www.loc.gov/mods/v3">
                    <xsl:value-of select="tokenize(.,'--')[2]"/>
                </xsl:element>
            </xsl:element>
        </xsl:element>
    </xsl:template>
    <xsl:template match="volume" mode="journal_article">
        <xsl:element name="detail" namespace="http://www.loc.gov/mods/v3">
            <xsl:attribute name="type">volume</xsl:attribute>
            <xsl:element name="number" namespace="http://www.loc.gov/mods/v3">
                <xsl:value-of select="."/>
            </xsl:element>
        </xsl:element>
    </xsl:template>
    <xsl:template mode="journal_article" match="date">
        <xsl:element name="date" namespace="http://www.loc.gov/mods/v3">
            <xsl:value-of select="."/>
        </xsl:element>
    </xsl:template>
    <xsl:template match="location" mode="book">
        <xsl:element name="place" namespace="http://www.loc.gov/mods/v3">
            <xsl:element name="placeTerm" namespace="http://www.loc.gov/mods/v3">
                <xsl:attribute name="type">text</xsl:attribute>
                <xsl:value-of select="."/>
            </xsl:element>
        </xsl:element>
    </xsl:template>
    <xsl:template match="date" mode="book">
        <xsl:element name="dateIssued" namespace="http://www.loc.gov/mods/v3">
            <xsl:value-of select="."/>
        </xsl:element>
    </xsl:template>
    <xsl:template match="booktitle" mode="all">
        <xsl:element name="titleInfo" namespace="http://www.loc.gov/mods/v3">
            <xsl:element name="title" namespace="http://www.loc.gov/mods/v3">
                <xsl:value-of select="."/>
            </xsl:element>
        </xsl:element>
    </xsl:template>
    <xsl:template match="publisher" mode="book">
        <xsl:element name="publisher" namespace="http://www.loc.gov/mods/v3">
            <xsl:value-of select="."/>
        </xsl:element>
    </xsl:template>
    <xsl:template match="notes" mode="journal_article">
        <xsl:comment>
            <xsl:value-of select="."/>
        </xsl:comment>
    </xsl:template>
    <xsl:template mode="journal_article" match="location"/>
    <xsl:template mode="journal_article" match="title"/>
</xsl:stylesheet>

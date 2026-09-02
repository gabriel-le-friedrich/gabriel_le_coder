<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:template match="/">
  <html>
  <head>
    <style>
      body {
        font-family: 'Courier New', Courier, monospace;
        background-color: #f0f0f0;
        padding: 20px;
      }
      .receipt {
        background: #fff;
        width: 320px;
        padding: 15px;
        margin: 0 auto;
        border: 1px solid #ccc;
        box-shadow: 0 0 5px rgba(0,0,0,0.1);
        white-space: pre-wrap;
        font-size: 12px;
        line-height: 1.2;
      }
      div { margin-bottom: 2px; }
    </style>
  </head>
  <body>
    <div class="receipt">
      <xsl:for-each select="Myreceipt/*/*">
        <div><xsl:value-of select="."/></div>
      </xsl:for-each>
    </div>
  </body>
  </html>
</xsl:template>
</xsl:stylesheet>
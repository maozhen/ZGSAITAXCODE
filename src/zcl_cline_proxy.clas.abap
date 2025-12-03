class ZCL_CLINE_PROXY definition
  public
  final
  create public .

public section.

  interfaces IF_HTTP_EXTENSION .
protected section.
private section.
ENDCLASS.



CLASS ZCL_CLINE_PROXY IMPLEMENTATION.


  METHOD IF_HTTP_EXTENSION~HANDLE_REQUEST.
    DATA(LV_METHOD) = SERVER->REQUEST->GET_METHOD( ).

    CASE LV_METHOD.
      WHEN 'GET'.
        SERVER->RESPONSE->SET_CDATA(
          DATA   = 'Hello LLM' " Character data
*          OFFSET = 0    " Offset into character data
*          LENGTH = -1   " Length of character data
        ).
      WHEN 'POST'.
        BREAK-POINT.
      WHEN OTHERS.
        SERVER->RESPONSE->SET_STATUS(
          CODE   = 405          " HTTP status code
          REASON = |Unsuport method { LV_METHOD }|        " HTTP status description
*         DETAILED_INFO = DETAILED_INFO
        ).
    ENDCASE.
  ENDMETHOD.
ENDCLASS.

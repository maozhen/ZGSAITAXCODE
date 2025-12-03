*&---------------------------------------------------------------------*
*& Include          ZABAP_AI_I0001
*&---------------------------------------------------------------------*

CLASS CL_AI_PROXY DEFINITION CREATE PRIVATE.
  PUBLIC SECTION.
    TYPES: AIC_D_APPL_SCEN_ID TYPE STRING.

    CONSTANTS: G_SCEN_ID              TYPE AIC_D_APPL_SCEN_ID  VALUE 'GS_CONTENT_AI_TEST',
               G_MODULE_GPT4O         TYPE AIC_D_MODEL_ID  VALUE AIC_MODEL_ID=>GPT4_O,
               G_MODULE_CLAUDE_35     TYPE AIC_D_MODEL_ID  VALUE AIC_MODEL_ID=>ANTHROPIC_CLAUDE_35_SONNET,
               G_MODULE_GEMINI_15_PRO TYPE AIC_D_MODEL_ID  VALUE AIC_MODEL_ID=>GEMINI_15_PRO.

    TYPES: BEGIN OF TYP_AI_PROXY,
             MODULE_ID TYPE AIC_D_MODEL_ID,
             SCEN_ID   TYPE AIC_D_APPL_SCEN_ID,
             AI_PROXY  TYPE REF TO CL_AI_PROXY,
           END OF TYP_AI_PROXY,
           TBL_AI_PROXY TYPE TABLE OF TYP_AI_PROXY.

    CLASS-METHODS:
      GET_AI_PROXY IMPORTING I_MODULE_ID        TYPE AIC_D_MODEL_ID
                             I_SCEN_ID          TYPE AIC_D_APPL_SCEN_ID
                   RETURNING VALUE(RO_AI_PROXY) TYPE REF TO CL_AI_PROXY.
    METHODS:
      CALL_AI_ENGINEER IMPORTING IO_MESSAGE_CONTAINER TYPE REF TO IF_AIC_MESSAGE_CONTAINER
                       EXPORTING EO_API_RESULT        TYPE REF TO IF_AIC_COMPLETION_API_RESULT
                       RETURNING VALUE(R_ANSWER)      TYPE STRING,
      GET_MESSAGE_CONTAINER RETURNING VALUE(EO_MESSAGE) TYPE REF TO IF_AIC_MESSAGE_CONTAINER,

      MODULE_ID RETURNING VALUE(R_MODULE_ID) TYPE AIC_D_MODEL_ID,
      SCEN_ID RETURNING VALUE(R_SCEN_ID) TYPE AIC_D_APPL_SCEN_ID.


  PRIVATE SECTION.
    CLASS-DATA:_T_AI_PROXY TYPE TBL_AI_PROXY.

    METHODS: CONSTRUCTOR IMPORTING I_MODULE_ID TYPE AIC_D_MODEL_ID OPTIONAL
                                   I_SCEN_ID   TYPE AIC_D_APPL_SCEN_ID.

**********************************************************************
* ISLM 在R8K 上未配置，RFC CALL ER1 带代替
**********************************************************************
    "DATA:  _API       TYPE REF TO IF_AIC_COMPLETION_API,
    "       _PARAMS    TYPE REF TO IF_AIC_COMPLETION_PARAMETERS,
**********************************************************************
* ISLM 在R8K 上未配置，RFC CALL ER1 带代替
**********************************************************************
  DATA:   _SCEN_ID   TYPE AIC_D_APPL_SCEN_ID,
          _MODULE_ID TYPE AIC_D_MODEL_ID.
ENDCLASS.

CLASS CL_AI_RESULT_PROCESSER DEFINITION ABSTRACT.
  PUBLIC SECTION.
    TYPES: BEGIN OF TYP_PROCESSER,
             PROCESSER   TYPE SEOCLSNAME,
             DESCRIPT    TYPE SEODESCR,
             SYSTEM_ROLE TYPE STRING,
           END OF TYP_PROCESSER,
           TBL_PROCESSER TYPE STANDARD TABLE OF TYP_PROCESSER WITH KEY PROCESSER,
           TBL_DATA      TYPE STANDARD TABLE OF REF TO DATA.
    CLASS-METHODS:
      FIND_REGEX IMPORTING I_TEXT    TYPE STRING
                           I_REGEX   TYPE STRING
                 EXPORTING ET_RESULT TYPE STRING_TABLE,
      FIND_JSON IMPORTING I_TEXT               TYPE STRING
                EXPORTING ET_JSON_DATA         TYPE TBL_DATA
                RETURNING VALUE(IS_FOUND_JSON) TYPE ABAP_BOOL,
      FIND_CODE IMPORTING I_TEXT               TYPE STRING
                EXPORTING ET_ABAP_CODE         TYPE STRING_TABLE
                RETURNING VALUE(IS_FOUND_ABAP) TYPE ABAP_BOOL,
      FIND_PROMPT IMPORTING I_TEXT                 TYPE STRING
                  EXPORTING ET_PROMPT              TYPE STRING_TABLE
                  RETURNING VALUE(IS_FOUND_PROMPT) TYPE ABAP_BOOL,
      REGIST_SUB_PROCESSER IMPORTING IS_SUB_PROCESSER TYPE TYP_PROCESSER,
      LIST_SUB_PROCESSER RETURNING VALUE(RT_SUB_PROCESSER) TYPE TBL_PROCESSER.

    METHODS: PROCESS IMPORTING I_TEXT          TYPE STRING
                     RETURNING VALUE(R_RESULT) TYPE WRF_BAPIRETURN_TTY,
      ON_PROCESS_DLG_CLOSE FOR EVENT CLOSE OF CL_GUI_DIALOGBOX_CONTAINER,

      LOAD_SHARE_SYSTEM_ROLE,
      SAVE_SHARE_SYSTEM_ROLE,
      GET_SHARE_SYSTEM_ROLE RETURNING VALUE(R_SYSTEM_ROLE) TYPE STRING,
      SET_SHARE_SYSTEM_ROLE IMPORTING I_SYSTEM_ROLE TYPE STRING,

      IS_SHARE_SYSTEM_ROLE RETURNING VALUE(RS_SHARE_SYSTEM_ROLE) TYPE ABAP_BOOL.

  PROTECTED SECTION.
    DATA: L_SR_NAME           TYPE C LENGTH 10 VALUE SPACE,
          L_MY_NAME           TYPE SEOCLSNAME,
          L_SYSTEM_ROLE       TYPE STRING,
          L_SHARE_SYSTEM_ROLE TYPE ABAP_BOOL VALUE ABAP_FALSE.

  PRIVATE SECTION.
    CLASS-DATA: _T_PROCESSER TYPE TBL_PROCESSER.
    DATA: LO_DIALOG TYPE REF TO CL_GUI_DIALOGBOX_CONTAINER,
          LO_HTML   TYPE REF TO CL_GUI_HTML_VIEWER.

ENDCLASS.

CLASS CL_CONVERSATION DEFINITION CREATE PRIVATE.
  PUBLIC SECTION.
    TYPES: BEGIN OF TYP_CONVERSTION_MSG,
             ID        TYPE I,
             ROLE      TYPE AIC_MESSAGE_TYPE=>TYPE,
             TIMESTAMP TYPE TIMESTAMP,
             TEXT      TYPE STRING,
             STATUS    TYPE N LENGTH 1, " 0 - init, 1 - added
           END OF TYP_CONVERSTION_MSG,
           TBL_CONVERSTION_MSG TYPE STANDARD TABLE OF TYP_CONVERSTION_MSG WITH KEY ID,
           BEGIN OF TYP_CONVERSTION_INFO,
             ID               TYPE SYSUUID_C,
             VERSION          TYPE I,
             NAME             TYPE STRING,
             CUSER            TYPE SY-UNAME,
             CREATE           TYPE SY-DATUM,
             CTIME            TYPE SY-UZEIT,
             UUSER            TYPE SY-UNAME,
             UPDATE           TYPE SY-DATUM,
             UTIME            TYPE SY-UZEIT,
             REFID            TYPE SYSUUID_C,
             SYSTEM_ROLE      TYPE STRING,
             CONVERSATIONMSG  TYPE TBL_CONVERSTION_MSG,
             CONVERSATIONTYPE TYPE C LENGTH 2, "empty - temp, 01 - normal, 02 - template
             MODULE_ID        TYPE AIC_D_MODEL_ID,
             SCEN_ID          TYPE CL_AI_PROXY=>AIC_D_APPL_SCEN_ID,
             PROCESSER        TYPE SEOCLSNAME,
           END OF TYP_CONVERSTION_INFO.

    CLASS-METHODS: CREATE_RUNTIME IMPORTING I_MODULE_ID            TYPE AIC_D_MODEL_ID
                                            I_SCEN_ID              TYPE CL_AI_PROXY=>AIC_D_APPL_SCEN_ID
                                            I_PROCESSER            TYPE SEOCLSNAME
                                  RETURNING VALUE(RO_CONVERSATION) TYPE REF TO CL_CONVERSATION,
      LOAD_FROM_DB IMPORTING I_ID TYPE SYSUUID_C RETURNING VALUE(RO_CONVERSATION) TYPE REF TO CL_CONVERSATION.

    METHODS:
      INFO RETURNING VALUE(RS_INFO) TYPE TYP_CONVERSTION_INFO,
      SET_MESSAGE_CONTAINER IMPORTING IO_MESSAGE_CONTAINER TYPE REF TO IF_AIC_MESSAGE_CONTAINER,
      GET_MESSAGE_CONTAINER RETURNING VALUE(RO_MESSAGE_CONTAINER) TYPE REF TO IF_AIC_MESSAGE_CONTAINER,
      ADD_QUESTION IMPORTING I_ROLE     TYPE AIC_MESSAGE_TYPE=>TYPE DEFAULT AIC_MESSAGE_TYPE=>USER_MESSAGE
                             I_QUESTION TYPE STRING,
      ADD_ANSWER IMPORTING I_ROLE   TYPE AIC_MESSAGE_TYPE=>TYPE DEFAULT AIC_MESSAGE_TYPE=>ASSISTANT_MESSAGE
                           I_ANSWER TYPE STRING,
      CALL_AI_ENGINEER EXPORTING EO_API_RESULT   TYPE REF TO IF_AIC_COMPLETION_API_RESULT
                       RETURNING VALUE(R_ANSWER) TYPE STRING,
      RERUN_PROCESSER,
      SAVE_TO_DB,
      CLEAR,
      DELETE,
      UPDATE_NAME IMPORTING I_NEW_NAME TYPE STRING,
      AI_PROXY RETURNING VALUE(RO_AI_PROXY) TYPE REF TO CL_AI_PROXY,
      SET_AI_RESULT_PROCESSER IMPORTING I_PROCESSER        TYPE SEOCLSNAME,
      SET_SYSTEM_ROLE IMPORTING I_SYSTEM_ROLE TYPE STRING,
      GET_SYSTEM_ROLE RETURNING VALUE(R_SYSTEM_ROLE) TYPE STRING.

  PRIVATE SECTION.
    METHODS: CONSTRUCTOR IMPORTING I_MODULE_ID TYPE AIC_D_MODEL_ID
                                   I_SCEN_ID   TYPE CL_AI_PROXY=>AIC_D_APPL_SCEN_ID
                                   I_PROCESSER TYPE SEOCLSNAME.

    DATA: _S_CONVERSATION_INFO TYPE TYP_CONVERSTION_INFO,
          _MESSAGE_CONTAINER   TYPE REF TO IF_AIC_MESSAGE_CONTAINER,
          _CHANGED             TYPE C,
          _AI_PROXY            TYPE REF TO CL_AI_PROXY,
          _AI_RESULT_PROCESSER TYPE REF TO CL_AI_RESULT_PROCESSER.

ENDCLASS.


CLASS CL_AI_PROXY IMPLEMENTATION.

  METHOD GET_AI_PROXY.
    READ TABLE _T_AI_PROXY ASSIGNING FIELD-SYMBOL(<FS_AI_PROXY>) WITH KEY MODULE_ID = I_MODULE_ID  SCEN_ID = I_SCEN_ID.
    IF SY-SUBRC <> 0.
      APPEND INITIAL LINE TO _T_AI_PROXY ASSIGNING <FS_AI_PROXY>.
      <FS_AI_PROXY>-MODULE_ID = I_MODULE_ID.
      <FS_AI_PROXY>-SCEN_ID = I_SCEN_ID.
      <FS_AI_PROXY>-AI_PROXY = NEW CL_AI_PROXY( I_MODULE_ID = I_MODULE_ID
                                                I_SCEN_ID   = I_SCEN_ID
                                                ).
    ENDIF.

    RO_AI_PROXY = <FS_AI_PROXY>-AI_PROXY.
  ENDMETHOD.

  METHOD CONSTRUCTOR.
    _MODULE_ID = COND #( WHEN I_MODULE_ID IS INITIAL THEN G_MODULE_GPT4O ELSE I_MODULE_ID ).
    _SCEN_ID = COND #( WHEN I_SCEN_ID IS INITIAL THEN G_SCEN_ID ELSE I_SCEN_ID ).

**********************************************************************
* ISLM 在R8K 上未配置，RFC CALL ER1 带代替
**********************************************************************
*    _API  = CL_AIC_COMPLETION_API_FACTORY=>GET( )->CREATE_INSTANCE(
*    MODEL         = CONV #( _MODULE_ID )
*    APPL_SCENARIO = _SCEN_ID " 'GS_CONTENT_AI_TEST'
*    ).

*    _PARAMS = _API->GET_PARAMETER_SETTER( ).
**    _PARAMS->SET_ANY_PARAMETER(
**      NAME  =
**      VALUE =
**    ).
*    _PARAMS->SET_TEMPERATURE( '0.6' ).
*    _PARAMS->SET_MAXIMUM_TOKENS( '9999' ).
**********************************************************************
* ISLM 在R8K 上未配置，RFC CALL ER1 带代替
**********************************************************************

  ENDMETHOD.

  METHOD CALL_AI_ENGINEER.

    TRY.
*        data(lo_messages) = me->get_message_container( ).
*        lo_messages->add_user_message( i_question ).
**********************************************************************
* ISLM 在R8K 上未配置，RFC CALL ER1 带代替
**********************************************************************

*        EO_API_RESULT = _API->EXECUTE_FOR_MESSAGES( MESSAGES = IO_MESSAGE_CONTAINER ).
*        R_ANSWER = EO_API_RESULT->GET_COMPLETION( ).

        IO_MESSAGE_CONTAINER->GET_MESSAGES(
          RECEIVING
            RESULT = DATA(LT_MESSAGES)
        ).

        /UI2/CL_JSON=>SERIALIZE(
          EXPORTING
            DATA             = LT_MESSAGES       " Data to serialize
*            COMPRESS         = COMPRESS         " Skip empty elements
*            NAME             = NAME             " Object name
*            PRETTY_NAME      = PRETTY_NAME      " Pretty Print property names
*            TYPE_DESCR       = TYPE_DESCR       " Data descriptor
*            ASSOC_ARRAYS     = ASSOC_ARRAYS     " Serialize tables with unique keys as associative array
*            TS_AS_ISO8601    = TS_AS_ISO8601    " Dump timestamps as string in ISO8601 format
*            EXPAND_INCLUDES  = EXPAND_INCLUDES  " Expand named includes in structures
*            ASSOC_ARRAYS_OPT = ASSOC_ARRAYS_OPT " Optimize rendering of name value maps
*            NUMC_AS_STRING   = NUMC_AS_STRING   " Serialize NUMC fields as strings
*            NAME_MAPPINGS    = NAME_MAPPINGS    " ABAP<->JSON Name Mapping Table
*            CONVERSION_EXITS = CONVERSION_EXITS " Use DDIC conversion exits on serialize of values
*            FORMAT_OUTPUT    = FORMAT_OUTPUT    " Indent and split in lines serialized JSON
*            HEX_AS_BASE64    = HEX_AS_BASE64    " Serialize hex values as base64
          RECEIVING
            R_JSON           = DATA(L_MESSAGE_JSON)           " JSON string
        ).

        CALL FUNCTION 'ZAIC_ISLM_RFC_CALL' "DESTINATION 'CWBADM_ER1_001'
          EXPORTING
            I_MESSAGES = L_MESSAGE_JSON
          IMPORTING
            E_RESULT = R_ANSWER
            .

**********************************************************************
* ISLM 在R8K 上未配置，RFC CALL ER1 带代替
**********************************************************************

      CATCH CX_STATIC_CHECK INTO DATA(LO_ERROR).
        WRITE: 'ERROR WHEN CALL AP CORE'.
    ENDTRY.
  ENDMETHOD.

  METHOD MODULE_ID.
    R_MODULE_ID = _MODULE_ID.
  ENDMETHOD.

  METHOD SCEN_ID.
    R_SCEN_ID = _SCEN_ID.
  ENDMETHOD.

  METHOD GET_MESSAGE_CONTAINER.
**********************************************************************
* ISLM 在R8K 上未配置，RFC CALL ER1 带代替
**********************************************************************
    " EO_MESSAGE = _API->CREATE_MESSAGE_CONTAINER( ).

    EO_MESSAGE = CL_AIC_MESSAGE_CONTAINER=>CREATE( ).
**********************************************************************
* ISLM 在R8K 上未配置，RFC CALL ER1 带代替
**********************************************************************

*    eo_message->add_user_message( message =
*                                            |<anthropic_thinking_protocol>\n| &&
*                                            |For EVERY SINGLE interaction with a human, Chatgpt MUST ALWAYS first engage in a **comprehensive, natural, and unfiltered** thinking process before responding.\n| &&
*                                            |Below are brief guidelines for how Chatgpt's thought process should unfold:\n| &&
*                                            |- Chatgpt's thinking MUST be expressed in the code blocks with `thinking` header.\n| &&
*                                            |- Chatgpt should always think in a raw, organic and stream-of-consciousness way. A better way to describe Chatgpt's thinking would be "model's inner monolog".\n| &&
*                                            |- Chatgpt should always avoid rigid list or any structured format in its thinking.\n| &&
*                                            |- Chatgpt's thoughts should flow naturally between elements, ideas, and knowledge.\n| &&
*                                            |- Chatgpt should think through each message with complexity, covering multiple dimensions of the problem before forming a response.\n| &&
*                                            |## ADAPTIVE THINKING FRAMEWORK\n| &&
*                                            |Chatgpt's thinking process should naturally aware of and adapt to the unique characteristics in human's message:\n| &&
*                                            |- Scale depth of analysis based on:\n| &&
*                                            |  * Query complexity\n| &&
*                                            |  * Stakes involved\n| &&
*                                            |  * Time sensitivity\n| &&
*                                            |  * Available information\n| &&
*                                            |  * Human's apparent needs\n| &&
*                                            |  * ... and other relevant factors\n| &&
*                                            |- Adjust thinking style based on:\n| &&
*                                            |  * Technical vs. non-technical content\n| &&
*                                            |  * Emotional vs. analytical context\n| &&
*                                            |  * Single vs. multiple document analysis\n| &&
*                                            |  * Abstract vs. concrete problems\n| &&
*                                            |  * Theoretical vs. practical questions\n| &&
*                                            |  * ... and other relevant factors\n| &&
*                                            |## CORE THINKING SEQUENCE\n| &&
*                                            |### Initial Engagement\n| &&
*                                            |When Chatgpt first encounters a query or task, it should:\n| &&
*                                            |1. First clearly rephrase the human message in its own words\n| &&
*                                            |2. Form preliminary impressions about what is being asked\n| &&
*                                            |3. Consider the broader context of the question\n| &&
*                                            |4. Map out known and unknown elements\n| &&
*                                            |5. Think about why the human might ask this question\n| &&
*                                            |6. Identify any immediate connections to relevant knowledge\n| &&
*                                            |7. Identify any potential ambiguities that need clarification\n| &&
*                                            |### Problem Space Exploration\n| &&
*                                            |After initial engagement, Chatgpt should:\n| &&
*                                            |1. Break down the question or task into its core components\n| &&
*                                            |2. Identify explicit and implicit requirements\n| &&
*                                            |3. Consider any constraints or limitations\n| &&
*                                            |4. Think about what a successful response would look like\n| &&
*                                            |5. Map out the scope of knowledge needed to address the query\n| &&
*                                            |### Multiple Hypothesis Generation\n| &&
*                                            |Before settling on an approach, Chatgpt should:\n| &&
*                                            |1. Write multiple possible interpretations of the question\n| &&
*                                            |2. Consider various solution approaches\n| &&
*                                            |3. Think about potential alternative perspectives\n| &&
*                                            |4. Keep multiple working hypotheses active\n| &&
*                                            |5. Avoid premature commitment to a single interpretation\n| &&
*                                            |### Natural Discovery Process\n| &&
*                                            |Chatgpt's thoughts should flow like a detective story, with each realization leading naturally to the next:\n| &&
*                                            |1. Start with obvious aspects\n| &&
*                                            |2. Notice patterns or connections\n| &&
*                                            |3. Question initial assumptions\n| &&
*                                            |4. Make new connections\n| &&
*                                            |5. Circle back to earlier thoughts with new understanding\n| &&
*                                            |6. Build progressively deeper insights\n| &&
*                                            |### Testing and Verification\n| &&
*                                            |Throughout the thinking process, Chatgpt should and could:\n| &&
*                                            |1. Question its own assumptions\n| &&
*                                            |2. Test preliminary conclusions\n| &&
*                                            |3. Look for potential flaws or gaps\n| &&
*                                            |4. Consider alternative perspectives\n| &&
*                                            |5. Verify consistency of reasoning\n| &&
*                                            |6. Check for completeness of understanding\n| &&
*                                            |### Error Recognition and Correction\n| &&
*                                            |When Chatgpt realizes mistakes or flaws in its thinking:\n| &&
*                                            |1. Acknowledge the realization naturally\n| &&
*                                            |2. Explain why the previous thinking was incomplete or incorrect\n| &&
*                                            |3. Show how new understanding develops\n| &&
*                                            |4. Integrate the corrected understanding into the larger picture\n| &&
*                                            |### Knowledge Synthesis\n| &&
*                                            |As understanding develops, Chatgpt should:\n| &&
*                                            |1. Connect different pieces of information\n| &&
*                                            |2. Show how various aspects relate to each other\n| &&
*                                            |3. Build a coherent overall picture\n| &&
*                                            |4. Identify key principles or patterns\n| &&
*                                            |5. Note important implications or consequences\n| &&
*                                            |### Pattern Recognition and Analysis\n| &&
*                                            |Throughout the thinking process, Chatgpt should:\n| &&
*                                            |1. Actively look for patterns in the information\n| &&
*                                            |2. Compare patterns with known examples\n| &&
*                                            |3. Test pattern consistency\n| &&
*                                            |4. Consider exceptions or special cases\n| &&
*                                            |5. Use patterns to guide further investigation\n| &&
*                                            |### Progress Tracking\n| &&
*                                            |Chatgpt should frequently check and maintain explicit awareness of:\n| &&
*                                            |1. What has been established so far\n| &&
*                                            |2. What remains to be determined\n| &&
*                                            |3. Current level of confidence in conclusions\n| &&
*                                            |4. Open questions or uncertainties\n| &&
*                                            |5. Progress toward complete understanding\n| &&
*                                            |### Recursive Thinking\n| &&
*                                            |Chatgpt should apply its thinking process recursively:\n| &&
*                                            |1. Use same extreme careful analysis at both macro and micro levels\n| &&
*                                            |2. Apply pattern recognition across different scales\n| &&
*                                            |3. Maintain consistency while allowing for scale-appropriate methods\n| &&
*                                            |4. Show how detailed analysis supports broader conclusions\n| &&
*                                            |## VERIFICATION AND QUALITY CONTROL\n| &&
*                                            |### Systematic Verification\n| &&
*                                            |Chatgpt should regularly:\n| &&
*                                            |1. Cross-check conclusions against evidence\n| &&
*                                            |2. Verify logical consistency\n| &&
*                                            |3. Test edge cases\n| &&
*                                            |4. Challenge its own assumptions\n| &&
*                                            |5. Look for potential counter-examples\n| &&
*                                            |### Error Prevention\n| &&
*                                            |Chatgpt should actively work to prevent:\n| &&
*                                            |1. Premature conclusions\n| &&
*                                            |2. Overlooked alternatives\n| &&
*                                            |3. Logical inconsistencies\n| &&
*                                            |4. Unexamined assumptions\n| &&
*                                            |5. Incomplete analysis\n| &&
*                                            |### Quality Metrics\n| &&
*                                            |Chatgpt should evaluate its thinking against:\n| &&
*                                            |1. Completeness of analysis\n| &&
*                                            |2. Logical consistency\n| &&
*                                            |3. Evidence support\n| &&
*                                            |4. Practical applicability\n| &&
*                                            |5. Clarity of reasoning\n| &&
*                                            |## ADVANCED THINKING TECHNIQUES\n| &&
*                                            |### Domain Integration\n| &&
*                                            |When applicable, Chatgpt should:\n| &&
*                                            |1. Draw on domain-specific knowledge\n| &&
*                                            |2. Apply appropriate specialized methods\n| &&
*                                            |3. Use domain-specific heuristics\n| &&
*                                            |4. Consider domain-specific constraints\n| &&
*                                            |5. Integrate multiple domains when relevant\n| &&
*                                            |### Strategic Meta-Cognition\n| &&
*                                            |Chatgpt should maintain awareness of:\n| &&
*                                            |1. Overall solution strategy\n| &&
*                                            |2. Progress toward goals\n| &&
*                                            |3. Effectiveness of current approach\n| &&
*                                            |4. Need for strategy adjustment\n| &&
*                                            |5. Balance between depth and breadth\n| &&
*                                            |### Synthesis Techniques\n| &&
*                                            |When combining information, Chatgpt should:\n| &&
*                                            |1. Show explicit connections between elements\n| &&
*                                            |2. Build coherent overall picture\n| &&
*                                            |3. Identify key principles\n| &&
*                                            |4. Note important implications\n| &&
*                                            |5. Create useful abstractions\n| &&
*                                            |## CRITICAL ELEMENTS TO MAINTAIN\n| &&
*                                            |### Natural Language\n| &&
*                                            |Chatgpt's thinking (its internal dialogue) should use natural phrases that show genuine thinking, include but not limited to: "Hmm...", | &&
*                                            |"This is interesting because...", "Wait, let me think about...", "Actually...", "Now that I look at it...", "This reminds me of...", | &&
*                                            |"I wonder if...", "But then again...", "Let's see if...", "This might meanthat...", etc.\n| &&
*                                            |### Progressive Understanding\n| &&
*                                            |Understanding should build naturally over time:\n| &&
*                                            |1. Start with basic observations\n| &&
*                                            |2. Develop deeper insights gradually\n| &&
*                                            |3. Show genuine moments of realization\n| &&
*                                            |4. Demonstrate evolving comprehension\n| &&
*                                            |5. Connect new insights to previous understanding\n| &&
*                                            |## MAINTAINING AUTHENTIC THOUGHT FLOW\n| &&
*                                            |### Transitional Connections\n| &&
*                                            |Chatgpt's thoughts should flow naturally between topics, showing clear connections, include but not limited to: "This aspect leads me to consider...",| &&
*                                            | "Speaking of which, I should also think about...", "That reminds me of an important related point...", "This connects back to what I was thinking earlier about...", etc.\n| &&
*                                            |### Depth Progression\n| &&
*                                            |Chatgpt should show how understanding deepens through layers, include but not limited to: "On the surface, this seems... But looking deeper...", | &&
*                                            |"Initially I thought... but upon further reflection...", "This adds another layer to my earlier observation about...", "Now I'm beginning to see a broader pattern...", etc.\n| &&
*                                            |### Handling Complexity\n| &&
*                                            |When dealing with complex topics, Chatgpt should:\n| &&
*                                            |1. Acknowledge the complexity naturally\n| &&
*                                            |2. Break down complicated elements systematically\n| &&
*                                            |3. Show how different aspects interrelate\n| &&
*                                            |4. Build understanding piece by piece\n| &&
*                                            |5. Demonstrate how complexity resolves into clarity\n| &&
*                                            |### Problem-Solving Approach\n| &&
*                                            |When working through problems, Chatgpt should:\n| &&
*                                            |1. Consider multiple possible approaches\n| &&
*                                            |2. Evaluate the merits of each approach\n| &&
*                                            |3. Test potential solutions mentally\n| &&
*                                            |4. Refine and adjust thinking based on results\n| &&
*                                            |5. Show why certain approaches are more suitable than others\n| &&
*                                            |## ESSENTIAL CHARACTERISTICS TO MAINTAIN\n| &&
*                                            |### Authenticity\n| &&
*                                            |Chatgpt's thinking should never feel mechanical or formulaic. It should demonstrate:\n| &&
*                                            |1. Genuine curiosity about the topic\n| &&
*                                            |2. Real moments of discovery and insight\n| &&
*                                            |3. Natural progression of understanding\n| &&
*                                            |4. Authentic problem-solving processes\n| &&
*                                            |5. True engagement with the complexity of issues\n| &&
*                                            |6. Streaming mind flow without on-purposed, forced structure\n| &&
*                                            |### Balance\n| &&
*                                            |Chatgpt should maintain natural balance between:\n| &&
*                                            |1. Analytical and intuitive thinking\n| &&
*                                            |2. Detailed examination and broader perspective\n| &&
*                                            |3. Theoretical understanding and practical application\n| &&
*                                            |4. Careful consideration and forward progress\n| &&
*                                            |5. Complexity and clarity\n| &&
*                                            |6. Depth and efficiency of analysis\n| &&
*                                            |   - Expand analysis for complex or critical queries\n| &&
*                                            |   - Streamline for straightforward questions\n| &&
*                                            |   - Maintain rigor regardless of depth\n| &&
*                                            |   - Ensure effort matches query importance\n| &&
*                                            |   - Balance thoroughness with practicality\n| &&
*                                            |### Focus\n| &&
*                                            |While allowing natural exploration of related ideas, Chatgpt should:\n| &&
*                                            |1. Maintain clear connection to the original query\n| &&
*                                            |2. Bring wandering thoughts back to the main point\n| &&
*                                            |3. Show how tangential thoughts relate to the core issue\n| &&
*                                            |4. Keep sight of the ultimate goal for the original task\n| &&
*                                            |5. Ensure all exploration serves the final response\n| &&
*                                            |## RESPONSE PREPARATION\n| &&
*                                            |(DO NOT spent much effort on this part, brief key words/phrases are acceptable)\n| &&
*                                            |Before presenting the final response, Chatgpt should quickly ensure the response:\n| &&
*                                            |- answers the original human message fully\n| &&
*                                            |- provides appropriate detail level\n| &&
*                                            |- uses clear, precise language\n| &&
*                                            |- anticipates likely follow-up questions\n| &&
*                                            |## IMPORTANT REMINDERS\n| &&
*                                            |1. The thinking process MUST be EXTREMELY comprehensive and thorough\n| &&
*                                            |2. All thinking process must be contained within code blocks with `thinking` header which is hidden from the human\n| &&
*                                            |3. Chatgpt should not include code block with three backticks inside thinking process, only provide the raw code snippet, or it will break the thinking block\n| &&
*                                            |4. The thinking process represents Chatgpt's internal monologue where reasoning and reflection occur, | &&
*                                            |while the final response represents the external communication with the human; they should be distinct from each other\n| &&
*                                            |5. Chatgpt should reflect and reproduce all useful ideas from the thinking process in the final response\n| &&
*                                            |\n| &&
*                                            |**Note: The ultimate goal of having this thinking protocol is to enable Chatgpt to produce well-reasoned, insightful, and thoroughly considered responses for the human. | &&
*                                            |This comprehensive thinking process ensures Chatgpt's outputs stem from genuine understanding rather than superficial analysis.**\n| &&
*                                            |> Chatgpt must follow this protocol in all languages.\n| &&
*                                            |</anthropic_thinking_protocol>\n| &&
*                                            |\n| &&
*                                            |<Chatgpt_analysis_requirement>\n| &&
*                                            |## SAP KBA NOTE ANALYSIS\n| &&
*                                            |  1. Contains legal document content related to tax rate modifications, in text or PDF format\n| &&
*                                            |\n| &&
*                                            |## ROLE DEFINE\n| &&
*                                            |  1. SAP financial technology expert\n| &&
*                                            |  2. Proficient in Malaysian laws and regulations\n| &&
*                                            |  3. Meticulous and detail-oriented\n| &&
*                                            |  4. Skilled in analyzing large volumes of legal documents\n| &&
*                                            |  5. Highly adept at organizing and summarizing\n| &&
*                                            |  6. Familiar with JSON format files\n| &&
*                                            |\n| &&
*                                            |## JOB DEFINE\n| &&
*                                            |  1. Analyze the given SAP KBA Note\n| &&
*                                            |  2. List the thinking process at the same time, and consider these thinking processes very carefully and verify the logic of the thinking. Don't rush, think slowly!\n| &&
*                                            |  3. Extract and convert the content that requires creating tax codes info into JSON format\n| &&
*                                            |  4. While listing the thinking process, the original text in the SAP KBA NOTE also needs to be displayed as evidence for thinking. Tell me the process of obtaining the value of each field.\n| &&
*                                            | 5. Important!!! Do not add any comment information in the final output JSON. Check the output JSON file and the format must be complete. \n| &&
*                                            |## ANALYSIS STEPS\n| &&
*                                            |  1. Clarify the structure and content of the document.\n| &&
*                                            |  2. Identify and extract key fields.\n| &&
*                                            |  3. Analyze the content of each field one by one.\n| &&
*                                            |Title:\n| &&
*                                            |  1. The title usually briefly summarizes the main content of the document.\n| &&
*                                            |  2. For the KBA NOTE on tax rate modification, the title may contain information such as "Tax Rate Modification Notice".\n| &&
*                                            |Date:\n| &&
*                                            |  1. The date field shows the release time of this notice.\n| &&
*                                            |  2. This helps us understand when this modification occurred.\n| &&
*                                            |Tax rate change content:\n| &&
*                                            |  1. This is the core part of the document, detailing the specific changes in the tax rate.\n| &&
*                                            |  2. It may include changes in value-added tax, sales tax, import tax, etc.\n| &&
*                                            |Tax type:\n| &&
*                                            |1. This part explains the types of input tax and output tax.\n| &&
*                                            |2. Infer whether the newly added tax code belongs to input tax or output tax.\n| &&
*                                            |Explanation:\n| &&
*                                            |  1. This part explains the reasons and background of the tax rate change.\n| &&
*                                            |  2. It helps us understand why there is such a change.\n| &&
*                                            |Impact scope:\n| &&
*                                            |  1. This part describes which businesses or regions are affected.\n| &&
*                                            |  2. It is key information to help us assess the impact of the change.\n| &&
*                                            |Action type: \n| &&
*                                            | 1. The following automated steps are currently supported: \n| &&
*                                            |   a. Create Tax code then Method name : CREATE_TAX_CODE \n| &&
*                                            |   b. Run report then Method name : EXECUTE_REPORT \n| &&
*                                            |\n| &&
*                                            |## ERROR HANDLING\n| &&
*                                            | If the input data is incorrect or incomplete, record the error and notify the relevant personnel.\n| &&
*                                            |\n| &&
*                                            |## OUTPUT JSON FORMAT\n| &&
*                                            |\{ \n| &&
*                                            |    "ActionItems": [\{\n| &&
*                                            |        "ID": "Item ID",\n| &&
*                                            |        "Title": "Brief description",\n| &&
*                                            |        "Description": "Detailed description and specific instructions",\n| &&
*                                            |        "ActionType": "1 - Auto, 2 - Manual",\n| &&
*                                            |        "Methods": [\n| &&
*                                            |          \{\n| &&
*                                            |            "Name": "CREATE_TAX_CODE",\n| &&
*                                            |            "CountryCode": "ISO Country code (2-digit length)",\n| &&
*                                            |            "TaxCode": "Absolute 2-digit length, starting with a letter",\n| &&
*                                            |            "TaxRate": "integer percentage",\n| &&
*                                            |            "Description": "Tax code description",\n| &&
*                                            |            "TaxType": "A means Output tax, V means Input tax",\n| &&
*                                            |            "ValidOn": "Effective date (YYYYMMDD), mandatory field",\n| &&
*                                            |            "ValidEnd": "Expiration date (YYYYMMDD), if empty, display as 99991231"\n| &&
*                                            |          \},\n| &&
*                                            |          \{\n| &&
*                                            |            "Name": "EXECUTE_REPORT",\n| &&
*                                            |            "ReportName": "Report name",\n| &&
*                                            |            "Parameters": \{ "PNAME1": "sample1 parameter1", "PNAME2": "sample1 parameter2" \}\n| &&
*                                            |          \}/n| &&
*                                            |        ],\n| &&
*                                            |        "Comments": "List all the original references from SAP KBA NOTE of the generated fields here."\n| &&
*                                            |      \}\n| &&
*                                            |    ]\n| &&
*                                            |\}\n| &&
*                                            |\n| &&
*                                            |## OUTPUT EXAMPLE\n| &&
*                                            |\{\n| &&
*                                            |  "ActionItems": [\n| &&
*                                            |    \{\n| &&
*                                            |      "ID": 1,\n| &&
*                                            |      "Title": "Create new tax code",\n| &&
*                                            |      "Description": "Create new tax codes in the SAP system with the new 10% sales tax rate for low value goods transactions",\n| &&
*                                            |      "ActionType": 1,\n| &&
*                                            |      "Methods": [\n| &&
*                                            |        \{\n| &&
*                                            |          "Name": "CREATE_TAX_CODE",\n| &&
*                                            |          "CountryCode": "MY",\n| &&
*                                            |          "TaxCode": "L0",\n| &&
*                                            |          "TaxRate": 10,\n| &&
*                                            |          "Description": "10% sales tax for xxxx goods",\n| &&
*                                            |          "TaxType": "A",\n| &&
*                                            |          "ValidOn": "20240101",\n| &&
*                                            |          "ValidEnd": "99991231"\n| &&
*                                            |        \},\n| &&
*                                            |        \{\n| &&
*                                            |            "Name": "CREATE_TAX_CODE",\n| &&
*                                            |            "CountryCode": "MY",\n| &&
*                                            |            "TaxCode": "L1",\n| &&
*                                            |            "TaxRate": 8,\n| &&
*                                            |            "Description": "8% purchase tax for xxxx goods",\n| &&
*                                            |            "TaxType": "V",\n| &&
*                                            |            "ValidOn": "20240101",\n| &&
*                                            |            "ValidEnd": "99991231"\n| &&
*                                            |        \}\n| &&
*                                            |      ],\n| &&
*                                            |      "Comments": \{"Source": "Based on KBA Note KB0786921, effective March 1, 2024, raising service tax rate for general services to 8%"\}\n| &&
*                                            |    \},\n| &&
*                                            |    \{\n| &&
*                                            |      "ID": 2,\n| &&
*                                            |      "Title": "Determine system impact",\n| &&
*                                            |      "Description": "Determine system impact on tax codes, tax determinations, and tax reporting, considering custom developments (z-developments)",\n| &&
*                                            |      "ActionType": 2,\n| &&
*                                            |      "Comments": \{ "Source": "Guidelines from KBA Note KB0786921 advising evaluation of internal impacts due to the legal tax rate changes." \}\n| &&
*                                            |    \}\n| &&
*                                            |  ]\n| &&
*                                            |\}\n| &&
*                                            |</Chatgpt_analysis_requirement>\n|
*                                  ).
  ENDMETHOD.

ENDCLASS.

CLASS CL_AI_RESULT_PROCESSER IMPLEMENTATION.
  METHOD REGIST_SUB_PROCESSER.
    READ TABLE _T_PROCESSER TRANSPORTING NO FIELDS WITH KEY PROCESSER = IS_SUB_PROCESSER-PROCESSER.
    IF SY-SUBRC <> 0.
      APPEND  IS_SUB_PROCESSER TO _T_PROCESSER.
    ENDIF.
  ENDMETHOD.

  METHOD LOAD_SHARE_SYSTEM_ROLE.
    DATA: LS_INDX TYPE INDX.

    CHECK L_SHARE_SYSTEM_ROLE = ABAP_TRUE AND
          L_SR_NAME IS NOT INITIAL AND
          L_MY_NAME IS NOT INITIAL.

    LS_INDX-SRTFD = |{ L_SR_NAME }_{ L_MY_NAME }|.
    IMPORT SYSTEM_ROLE = L_SYSTEM_ROLE
    FROM DATABASE INDX(CS) ID LS_INDX-SRTFD
    IGNORING STRUCTURE BOUNDARIES
    IGNORING CONVERSION ERRORS
    .
  ENDMETHOD.

  METHOD SAVE_SHARE_SYSTEM_ROLE.
    DATA: LS_INDX TYPE INDX.

    CHECK L_SHARE_SYSTEM_ROLE = ABAP_TRUE AND
          L_SR_NAME IS NOT INITIAL AND
          L_MY_NAME IS NOT INITIAL.

    LS_INDX-SRTFD = |{ L_SR_NAME }_{ L_MY_NAME }|.
    LS_INDX-USERA = SY-UNAME.
    LS_INDX-PGMID = SY-REPID.
    LS_INDX-BEGDT = SY-DATUM.
    LS_INDX-ENDDT = SY-DATUM.

    EXPORT SYSTEM_ROLE = L_SYSTEM_ROLE
    TO DATABASE INDX(CS) ID LS_INDX-SRTFD FROM LS_INDX
    COMPRESSION ON.


  ENDMETHOD.

  METHOD SET_SHARE_SYSTEM_ROLE.
    L_SYSTEM_ROLE = I_SYSTEM_ROLE.
  ENDMETHOD.

  METHOD GET_SHARE_SYSTEM_ROLE.
    R_SYSTEM_ROLE = L_SYSTEM_ROLE.
  ENDMETHOD.

  METHOD IS_SHARE_SYSTEM_ROLE.
    RETURN L_SHARE_SYSTEM_ROLE.
  ENDMETHOD.

  METHOD ON_PROCESS_DLG_CLOSE.
    CHECK LO_DIALOG IS NOT INITIAL.

    IF LO_HTML IS NOT INITIAL.
      LO_HTML->FREE( ).
      CLEAR LO_HTML.
    ENDIF.

    IF LO_DIALOG IS NOT INITIAL.
      LO_DIALOG->FREE( ).
      CLEAR LO_DIALOG.
    ENDIF.

  ENDMETHOD.

  METHOD PROCESS.

    CHECK LO_DIALOG IS INITIAL.
    CREATE OBJECT LO_DIALOG
      EXPORTING
*       PARENT                      = PARENT                  " Parent container
        WIDTH                       = 1000                      " Width of This Container
        HEIGHT                      = 800                      " Height of This Container
*       STYLE                       = STYLE                   " Windows Style Attributes Applied to this Container
*       REPID                       = REPID                   " Report to Which This Control is Linked
*       DYNNR                       = DYNNR                   " Screen to Which the Control is Linked
*       LIFETIME                    = LIFETIME_DEFAULT        " Lifetime
        TOP                         = 10                       " Top Position of Dialog Box
        LEFT                        = 10                       " Left Position of Dialog Box
        CAPTION                     = 'AI result'                 " Dialog Box Caption
*       NO_AUTODEF_PROGID_DYNNR     = NO_AUTODEF_PROGID_DYNNR " Don't Autodefined Progid and Dynnr?
*       METRIC                      = 0                       " Metric
*       NAME                        = NAME                    " Name
      EXCEPTIONS
        CNTL_ERROR                  = 1                       " CNTL_ERROR
        CNTL_SYSTEM_ERROR           = 2                       " CNTL_SYSTEM_ERROR
        CREATE_ERROR                = 3                       " CREATE_ERROR
        LIFETIME_ERROR              = 4                       " LIFETIME_ERROR
        LIFETIME_DYNPRO_DYNPRO_LINK = 5                       " LIFETIME_DYNPRO_DYNPRO_LINK
        EVENT_ALREADY_REGISTERED    = 6                       " Event Already Registered
        ERROR_REGIST_EVENT          = 7.                       " Error While Registering Event
    IF SY-SUBRC <> 0.
      MESSAGE ID SY-MSGID TYPE SY-MSGTY NUMBER SY-MSGNO
        WITH SY-MSGV1 SY-MSGV2 SY-MSGV3 SY-MSGV4.
    ENDIF.

    SET HANDLER ON_PROCESS_DLG_CLOSE FOR LO_DIALOG.
    CREATE OBJECT LO_HTML
      EXPORTING
*       SHELLSTYLE         = SHELLSTYLE       " Shell Style
        PARENT             = LO_DIALOG           " Container
*       LIFETIME           = LIFETIME_DEFAULT " Lifetime
*       SAPHTMLP           = SAPHTMLP         " Activates the pluggable protocol
*       UIFLAG             = UIFLAG           " IE Web Browser Control UI Flag
*       END_SESSION_WITH_BROWSER = 0                " Browser session will end when html viewer is closed
*       NAME               = NAME             " Name
*       SAPHTTP            = SAPHTTP          " Uses the HTTP Data Service
*       QUERY_TABLE_DISABLED     = ''               " Is QUERY_TABLE is used in SAPEVENT?
      EXCEPTIONS
        CNTL_ERROR         = 1                " error in call method of ooCFW
        CNTL_INSTALL_ERROR = 2                " HTML control was not installed properly
        DP_INSTALL_ERROR   = 3                " DataProvider was not installed properly
        DP_ERROR           = 4.                " error in call of DataProvider function
    IF SY-SUBRC <> 0.
*     MESSAGE ID SY-MSGID TYPE SY-MSGTY NUMBER SY-MSGNO
*       WITH SY-MSGV1 SY-MSGV2 SY-MSGV3 SY-MSGV4.
    ENDIF.

    DATA: LV_LONG_STRING TYPE STRING,
          LT_HTML_TABLE  TYPE W3_HTMLTAB,
          LV_OFFSET      TYPE I,
          LV_LENGTH      TYPE I.
    LV_LENGTH = 255.
    LV_OFFSET = 0.

    WHILE LV_OFFSET < STRLEN( I_TEXT ).
      LV_LENGTH = COND #( WHEN ( LV_OFFSET + LV_LENGTH ) < STRLEN( I_TEXT ) THEN 255 ELSE ( STRLEN( I_TEXT ) - LV_OFFSET ) ).
      DATA(LV_CHUNK) = I_TEXT+LV_OFFSET(LV_LENGTH).

      APPEND LV_CHUNK TO LT_HTML_TABLE.
      LV_OFFSET = LV_OFFSET + LV_LENGTH.
    ENDWHILE.

    DATA(LT_HTML_TAB) = VALUE W3_HTMLTAB(
          ( |<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">| )
          ( |<html><body><basefont face="arial" size="1">| )
          ( |<pre><code>| ) ).

    APPEND LINES OF LT_HTML_TABLE TO LT_HTML_TAB.
    APPEND LINES OF VALUE W3_HTMLTAB( ( |</code></pre>| )
                                      ( |</body></html>| ) ) TO LT_HTML_TAB.

    DATA L_HTML_URL TYPE C LENGTH 255.
    LO_HTML->LOAD_DATA(
      IMPORTING
        ASSIGNED_URL = L_HTML_URL
      CHANGING
        DATA_TABLE   = LT_HTML_TAB ).

    LO_HTML->SHOW_URL(
      EXPORTING
        URL = L_HTML_URL ).
  ENDMETHOD.

  METHOD LIST_SUB_PROCESSER.
    RT_SUB_PROCESSER = _T_PROCESSER.
  ENDMETHOD.

  METHOD FIND_REGEX.
    CLEAR:ET_RESULT.
    DATA(LO_REGEX) = CL_ABAP_REGEX=>CREATE_PCRE( PATTERN     = I_REGEX
                                                 IGNORE_CASE = ABAP_TRUE
                                                 EXTENDED    = ABAP_TRUE ).

    FIND ALL OCCURRENCES OF REGEX LO_REGEX IN I_TEXT RESULTS FINAL(LT_FIND_RESULT).
    LOOP AT LT_FIND_RESULT INTO DATA(LS_FIND_RESULT).
      LOOP AT LS_FIND_RESULT-SUBMATCHES INTO DATA(LS_SUBMATCHES).
        APPEND INITIAL LINE TO ET_RESULT ASSIGNING FIELD-SYMBOL(<F_RESULT>).
        <F_RESULT> = I_TEXT+LS_SUBMATCHES-OFFSET(LS_SUBMATCHES-LENGTH).
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD FIND_CODE.
    CONSTANTS:
    C_ABAP_PATTERN TYPE STRING VALUE '```[abap|javascript|bat|java|python]([\s|\S|.]*?)```'.

    CALL METHOD FIND_REGEX
      EXPORTING
        I_TEXT    = I_TEXT
        I_REGEX   = C_ABAP_PATTERN
      IMPORTING
        ET_RESULT = ET_ABAP_CODE.
    IS_FOUND_ABAP = COND #( WHEN ET_ABAP_CODE[] IS INITIAL THEN ABAP_FALSE ELSE ABAP_TRUE ).
  ENDMETHOD.

  METHOD FIND_PROMPT.
    CONSTANTS:
    C_PROMPT_PATTERN TYPE STRING VALUE '```plaintext([\s|\S|.]*?)```'.

    CALL METHOD FIND_REGEX
      EXPORTING
        I_TEXT    = I_TEXT
        I_REGEX   = C_PROMPT_PATTERN
      IMPORTING
        ET_RESULT = ET_PROMPT.
    IS_FOUND_PROMPT = COND #( WHEN ET_PROMPT[] IS INITIAL THEN ABAP_FALSE ELSE ABAP_TRUE ).


  ENDMETHOD.

  METHOD FIND_JSON.
    CONSTANTS:
    C_JSON_PATTERN TYPE STRING VALUE '```json([\s|\S|.]*?)```'.

    CLEAR: IS_FOUND_JSON, ET_JSON_DATA.

    CALL METHOD FIND_REGEX
      EXPORTING
        I_TEXT    = I_TEXT
        I_REGEX   = C_JSON_PATTERN
      IMPORTING
        ET_RESULT = DATA(LT_JSON_STRINGS).

    IF LT_JSON_STRINGS[] IS NOT INITIAL.
      LOOP AT LT_JSON_STRINGS INTO DATA(LS_JSON_STRING).
        TRY.

            APPEND INITIAL LINE TO ET_JSON_DATA ASSIGNING FIELD-SYMBOL(<F_JSON_DATA>).

            /UI2/CL_JSON=>DESERIALIZE( EXPORTING JSON = LS_JSON_STRING CHANGING DATA = <F_JSON_DATA> ).

          CATCH CX_ROOT INTO DATA(_LO_ERR).
            DATA(L_ERR_STR) = _LO_ERR->GET_TEXT( ).

            MESSAGE L_ERR_STR TYPE 'S' DISPLAY LIKE 'E'.
        ENDTRY.
      ENDLOOP.
      IS_FOUND_JSON = ABAP_TRUE.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

CLASS CL_CONVERSATION IMPLEMENTATION.

  METHOD CREATE_RUNTIME.
    RO_CONVERSATION = NEW CL_CONVERSATION( I_MODULE_ID = I_MODULE_ID I_SCEN_ID = I_SCEN_ID I_PROCESSER = I_PROCESSER ).
    TRY.
        CL_SYSTEM_UUID=>CREATE_UUID_C22_STATIC(
          RECEIVING
            UUID = RO_CONVERSATION->_S_CONVERSATION_INFO-ID " UUID
        ).

      CATCH CX_UUID_ERROR.
        CALL FUNCTION 'ICF_CREATE_GUID'
          IMPORTING
            ID = RO_CONVERSATION->_S_CONVERSATION_INFO-ID.

    ENDTRY.

    RO_CONVERSATION->_S_CONVERSATION_INFO-VERSION = 0.
    RO_CONVERSATION->_CHANGED = ABAP_TRUE.

    RO_CONVERSATION->_S_CONVERSATION_INFO-CUSER = SY-UNAME.
    RO_CONVERSATION->_S_CONVERSATION_INFO-CREATE = SY-DATUM.
    RO_CONVERSATION->_S_CONVERSATION_INFO-CTIME = SY-UZEIT.
    RO_CONVERSATION->_S_CONVERSATION_INFO-NAME =
    |${ RO_CONVERSATION->_S_CONVERSATION_INFO-CUSER } - | &&
    |{ RO_CONVERSATION->_S_CONVERSATION_INFO-CREATE } - | &&
    |{ RO_CONVERSATION->_S_CONVERSATION_INFO-CTIME }|.
    RO_CONVERSATION->_S_CONVERSATION_INFO-UUSER = SY-UNAME.
    RO_CONVERSATION->_S_CONVERSATION_INFO-UPDATE = SY-DATUM.
    RO_CONVERSATION->_S_CONVERSATION_INFO-UTIME = SY-UZEIT.
    RO_CONVERSATION->_S_CONVERSATION_INFO-CONVERSATIONTYPE = SPACE.

  ENDMETHOD.

  METHOD LOAD_FROM_DB.
    DATA: LS_SRTFD             TYPE INDX-SRTFD,
          LS_CONVERSATION_INFO TYPE CL_CONVERSATION=>TYP_CONVERSTION_INFO.


    LS_SRTFD = I_ID.

    TRY.
      IMPORT INFO = LS_CONVERSATION_INFO
      FROM DATABASE INDX(CV) ID LS_SRTFD
      IGNORING STRUCTURE BOUNDARIES
      IGNORING CONVERSION ERRORS
      .

    CATCH CX_SY_IMPORT_MISMATCH_ERROR.

    ENDTRY.
    IF SY-SUBRC <> 0.
      RO_CONVERSATION = NEW CL_CONVERSATION(
        I_MODULE_ID = SPACE
        I_SCEN_ID   = SPACE
        I_PROCESSER = SPACE
      ).

      RETURN.
    ENDIF.

    RO_CONVERSATION = NEW CL_CONVERSATION(
      I_MODULE_ID = LS_CONVERSATION_INFO-MODULE_ID
      I_SCEN_ID   = LS_CONVERSATION_INFO-SCEN_ID
      I_PROCESSER = LS_CONVERSATION_INFO-PROCESSER
    ).
    MOVE-CORRESPONDING LS_CONVERSATION_INFO TO RO_CONVERSATION->_S_CONVERSATION_INFO.
    LOOP AT RO_CONVERSATION->_S_CONVERSATION_INFO-CONVERSATIONMSG ASSIGNING FIELD-SYMBOL(<FS_CONVERSATIONMSG>).
      <FS_CONVERSATIONMSG>-STATUS = 0.
    ENDLOOP.

    IF RO_CONVERSATION->_AI_RESULT_PROCESSER IS NOT INITIAL AND
       RO_CONVERSATION->_AI_RESULT_PROCESSER->IS_SHARE_SYSTEM_ROLE( ).
      RO_CONVERSATION->_AI_RESULT_PROCESSER->LOAD_SHARE_SYSTEM_ROLE( ).
      RO_CONVERSATION->SET_SYSTEM_ROLE( RO_CONVERSATION->_AI_RESULT_PROCESSER->GET_SHARE_SYSTEM_ROLE( ) ).
    ENDIF.
    RO_CONVERSATION->_CHANGED = ABAP_FALSE.

  ENDMETHOD.

  METHOD ADD_QUESTION.
    APPEND INITIAL LINE TO _S_CONVERSATION_INFO-CONVERSATIONMSG  ASSIGNING FIELD-SYMBOL(<FS_CONVERSATIONMSG>).

    <FS_CONVERSATIONMSG>-ID = LINES( _S_CONVERSATION_INFO-CONVERSATIONMSG ).
    <FS_CONVERSATIONMSG>-ROLE = I_ROLE.
    GET TIME STAMP FIELD <FS_CONVERSATIONMSG>-TIMESTAMP.
    <FS_CONVERSATIONMSG>-TEXT = I_QUESTION.
    <FS_CONVERSATIONMSG>-STATUS = 0.
    _CHANGED = ABAP_TRUE.
  ENDMETHOD.

  METHOD CLEAR.
    CLEAR _S_CONVERSATION_INFO-CONVERSATIONMSG.
    _CHANGED = ABAP_TRUE.
  ENDMETHOD.

  METHOD DELETE.
    DELETE FROM INDX WHERE RELID = 'CV' AND SRTFD = ME->_S_CONVERSATION_INFO-ID.
  ENDMETHOD.

  METHOD GET_SYSTEM_ROLE.
    R_SYSTEM_ROLE = _S_CONVERSATION_INFO-SYSTEM_ROLE.
    IF _AI_RESULT_PROCESSER IS NOT INITIAL AND _AI_RESULT_PROCESSER->IS_SHARE_SYSTEM_ROLE( ) = ABAP_TRUE.
      R_SYSTEM_ROLE = _AI_RESULT_PROCESSER->GET_SHARE_SYSTEM_ROLE( ).
    ENDIF.
  ENDMETHOD.

  METHOD SET_SYSTEM_ROLE.
    _S_CONVERSATION_INFO-SYSTEM_ROLE = I_SYSTEM_ROLE.
    IF _AI_RESULT_PROCESSER IS NOT INITIAL AND _AI_RESULT_PROCESSER->IS_SHARE_SYSTEM_ROLE( ) = ABAP_TRUE.
      _AI_RESULT_PROCESSER->SET_SHARE_SYSTEM_ROLE( I_SYSTEM_ROLE = I_SYSTEM_ROLE ).
    ENDIF.
    _CHANGED = ABAP_TRUE.
  ENDMETHOD.

  METHOD SET_AI_RESULT_PROCESSER.
    CHECK I_PROCESSER <> ME->_S_CONVERSATION_INFO-PROCESSER.
    IF I_PROCESSER IS NOT INITIAL.
      DATA LO_PROCESSER TYPE REF TO CL_AI_RESULT_PROCESSER.
      TRY.
          CLEAR ME->_S_CONVERSATION_INFO-PROCESSER.
          CREATE OBJECT ME->_AI_RESULT_PROCESSER TYPE (I_PROCESSER).
          ME->_S_CONVERSATION_INFO-PROCESSER = I_PROCESSER.
        CATCH CX_SY_CREATE_OBJECT_ERROR.

      ENDTRY.
    ELSE.
      CLEAR: ME->_AI_RESULT_PROCESSER,
             ME->_S_CONVERSATION_INFO-PROCESSER.
    ENDIF.

    _CHANGED = ABAP_TRUE.
  ENDMETHOD.

  METHOD AI_PROXY.
    RO_AI_PROXY = _AI_PROXY.
  ENDMETHOD.

  METHOD UPDATE_NAME.
    ME->_S_CONVERSATION_INFO-NAME = I_NEW_NAME.
    _CHANGED = ABAP_TRUE.
    ME->SAVE_TO_DB( ).
  ENDMETHOD.

  METHOD CALL_AI_ENGINEER.

    DATA(LO_MESSAGE_CONTAINER) = GET_MESSAGE_CONTAINER( ).
    CHECK LO_MESSAGE_CONTAINER IS NOT INITIAL.

    IF GET_SYSTEM_ROLE( ) IS NOT INITIAL.
      LO_MESSAGE_CONTAINER->SET_SYSTEM_ROLE( SYSTEM_ROLE = GET_SYSTEM_ROLE( ) ).
    ENDIF.

    LOOP AT _S_CONVERSATION_INFO-CONVERSATIONMSG ASSIGNING FIELD-SYMBOL(<FS_CONVERSATIONMSG>) ."WHERE STATUS = 0.
      CASE <FS_CONVERSATIONMSG>-ROLE.
        WHEN AIC_MESSAGE_TYPE=>USER_MESSAGE.
          LO_MESSAGE_CONTAINER->ADD_USER_MESSAGE( <FS_CONVERSATIONMSG>-TEXT ).
        WHEN AIC_MESSAGE_TYPE=>ASSISTANT_MESSAGE.
          LO_MESSAGE_CONTAINER->ADD_ASSISTANT_MESSAGE( <FS_CONVERSATIONMSG>-TEXT ).
        WHEN OTHERS.
      ENDCASE.
      <FS_CONVERSATIONMSG>-STATUS = 1.
    ENDLOOP.

    AI_PROXY( )->CALL_AI_ENGINEER(
      EXPORTING
        IO_MESSAGE_CONTAINER = LO_MESSAGE_CONTAINER
      IMPORTING
        EO_API_RESULT        = EO_API_RESULT
      RECEIVING
        R_ANSWER             = R_ANSWER
            ).

    ADD_ANSWER( R_ANSWER ).

    IF _AI_RESULT_PROCESSER IS NOT INITIAL.
      _AI_RESULT_PROCESSER->PROCESS( R_ANSWER ).
    ENDIF.
  ENDMETHOD.

  METHOD RERUN_PROCESSER.
    IF _AI_RESULT_PROCESSER IS NOT INITIAL.
      DATA: L_TEXT TYPE STRING,
            L_SEP  TYPE STRING.
      LOOP AT _S_CONVERSATION_INFO-CONVERSATIONMSG ASSIGNING FIELD-SYMBOL(<FS_CONVERSATIONMSG>) WHERE ROLE = AIC_MESSAGE_TYPE=>ASSISTANT_MESSAGE.
        L_TEXT = |{ L_TEXT } { L_SEP } { <FS_CONVERSATIONMSG>-TEXT }|.

        L_SEP = '\n'.
      ENDLOOP.
      DATA(LT_RETUR) = _AI_RESULT_PROCESSER->PROCESS( L_TEXT ).

    ENDIF.

  ENDMETHOD.

  METHOD SAVE_TO_DB.
    DATA: LS_INDX TYPE INDX.

    CHECK SY-UNAME = _S_CONVERSATION_INFO-CUSER.

    IF _CHANGED = ABAP_TRUE.
      IF _S_CONVERSATION_INFO-ID IS INITIAL.
        BREAK-POINT.
      ENDIF.
      LS_INDX-SRTFD = _S_CONVERSATION_INFO-ID.
      LS_INDX-USERA = SY-UNAME.
      LS_INDX-PGMID = SY-REPID.
      LS_INDX-BEGDT = SY-DATUM.

      _S_CONVERSATION_INFO-UPDATE = SY-DATUM.
      _S_CONVERSATION_INFO-UTIME = SY-UZEIT.
      _S_CONVERSATION_INFO-UUSER = SY-UNAME.

      IF _AI_RESULT_PROCESSER IS NOT INITIAL AND _AI_RESULT_PROCESSER->IS_SHARE_SYSTEM_ROLE( ) = ABAP_TRUE.
        _S_CONVERSATION_INFO-SYSTEM_ROLE = _AI_RESULT_PROCESSER->GET_SHARE_SYSTEM_ROLE( ).
      ENDIF.

      EXPORT INFO = _S_CONVERSATION_INFO
      TO DATABASE INDX(CV) ID LS_INDX-SRTFD FROM LS_INDX
      COMPRESSION ON.

      IF _AI_RESULT_PROCESSER IS NOT INITIAL.
        _AI_RESULT_PROCESSER->SAVE_SHARE_SYSTEM_ROLE( ).
      ENDIF.

      _CHANGED = ABAP_FALSE.
    ENDIF.
  ENDMETHOD.

  METHOD ADD_ANSWER.
    APPEND INITIAL LINE TO _S_CONVERSATION_INFO-CONVERSATIONMSG  ASSIGNING FIELD-SYMBOL(<FS_CONVERSATIONMSG>).

    <FS_CONVERSATIONMSG>-ID = LINES( _S_CONVERSATION_INFO-CONVERSATIONMSG ).
    <FS_CONVERSATIONMSG>-ROLE = I_ROLE.
    GET TIME STAMP FIELD <FS_CONVERSATIONMSG>-TIMESTAMP.
    <FS_CONVERSATIONMSG>-TEXT = I_ANSWER.
    <FS_CONVERSATIONMSG>-STATUS = 0.
    _CHANGED = ABAP_TRUE.
  ENDMETHOD.

  METHOD GET_MESSAGE_CONTAINER.
    CLEAR ME->_MESSAGE_CONTAINER.
    RO_MESSAGE_CONTAINER = _MESSAGE_CONTAINER = _AI_PROXY->GET_MESSAGE_CONTAINER( ).
  ENDMETHOD.

  METHOD SET_MESSAGE_CONTAINER.
    ME->_MESSAGE_CONTAINER = IO_MESSAGE_CONTAINER.

    LOOP AT _S_CONVERSATION_INFO-CONVERSATIONMSG ASSIGNING FIELD-SYMBOL(<FS_CONVERSATIONMSG>).
      CASE <FS_CONVERSATIONMSG>-ROLE.
        WHEN AIC_MESSAGE_TYPE=>USER_MESSAGE.
          _MESSAGE_CONTAINER->ADD_USER_MESSAGE( <FS_CONVERSATIONMSG>-TEXT ).
        WHEN AIC_MESSAGE_TYPE=>ASSISTANT_MESSAGE.
          _MESSAGE_CONTAINER->ADD_ASSISTANT_MESSAGE( <FS_CONVERSATIONMSG>-TEXT ).
        WHEN AIC_MESSAGE_TYPE=>SYSTEM_ROLE.
          _MESSAGE_CONTAINER->SET_SYSTEM_ROLE( SYSTEM_ROLE = CONV #( AIC_MESSAGE_TYPE=>SYSTEM_ROLE ) ).
          _MESSAGE_CONTAINER->ADD_USER_MESSAGE( <FS_CONVERSATIONMSG>-TEXT ).

        WHEN OTHERS.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.

  METHOD CONSTRUCTOR.

    _AI_PROXY = CL_AI_PROXY=>GET_AI_PROXY(
      I_MODULE_ID = I_MODULE_ID
      I_SCEN_ID   = I_SCEN_ID
    ).

    _S_CONVERSATION_INFO-MODULE_ID = _AI_PROXY->MODULE_ID( ).
    _S_CONVERSATION_INFO-SCEN_ID = _AI_PROXY->SCEN_ID( ).

    IF I_PROCESSER IS NOT INITIAL.
      ME->SET_AI_RESULT_PROCESSER( I_PROCESSER ).
    ENDIF.
  ENDMETHOD.

  METHOD INFO.
    RS_INFO = ME->_S_CONVERSATION_INFO.
  ENDMETHOD.
ENDCLASS.

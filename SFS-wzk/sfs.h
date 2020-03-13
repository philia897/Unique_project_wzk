#ifndef SFS_H
#define SFS_H

// simple file storage
#include <stdint.h>

#define FILE_HEAD 84
#define TABLE_HEAD 24

typedef struct SFSVarchar{
    uint32_t len; /* length of the varchar string(buf[]) */
    char buf[];
}SFSVarchar;

typedef struct SFSTable{
    uint32_t size;               /* size of the table */
    uint32_t freeSpace;           /* free space left in the table */
    uint32_t storSize;          /* Space usd to store data in the table(except header and recordMeta) */
    uint32_t varcharNum;         /* number of varchars in the table */
    uint32_t recordNum;           /* number of record in the table */
    uint32_t recordSize;         /* size of a record */

    /* !!! when store in the file, the pointer should change to offset !!!*/
    struct SFSVarchar *recordMeta;   /* pointer of the recordMeta */
    struct SFSVarchar *lastVarchar;  /* pointer of the lastest inserted recordMeta */
    struct SFSDatabase *database;    /* pointer of the database */
    char buf[];
}SFSTable;

typedef struct SFSDatabase{
    uint32_t magic;     /* sfs magic number */
    uint32_t crc;       /* CRC32 checksum of the file (except "magic" & "crc") */
    uint32_t version;   /* sfs version number of the file */
    uint32_t size;      /* size of the file */
    uint8_t tableNum;   /* number of tables int the file (no more than 16)*/
    uint8_t pad[3];     /* reserved */
    /* !!! when store in the file, the pointer should change to offset !!!*/
    SFSTable *table[16]; /* pointer of the tables */
    char buf[];
}SFSDatabase;

#define BUILD_BUG_ON(condition) ((void)sizeof(char[1 - 2*!!(condition)]))
inline void sfsCompileTest(){
    BUILD_BUG_ON(__SIZEOF_POINTER__ != 4);
    BUILD_BUG_ON(sizeof(SFSVarchar) != 4);
    BUILD_BUG_ON(sizeof(SFSTable) != 36);
    BUILD_BUG_ON(sizeof(SFSDatabase) != 84);
}

int sfsVarcharCons(SFSVarchar *varchar, const char* src);   //fi
SFSVarchar* sfsVarcharCreate(uint32_t varcharSize, const char* src);   //fi
int sfsVarcharRelease(SFSVarchar *varchar);   //fi

int sfsTableCons(SFSTable *table, uint32_t initStorSize, const SFSVarchar *recordMeta, SFSDatabase *db);
SFSTable* sfsTableCreate(uint32_t initStorSize, const SFSVarchar *recordMeta, SFSDatabase *db);  //fi
int sfsTableRelease(SFSTable *table);    //fi
int sfsTableReserve(SFSTable **table, uint32_t storSize);   //fi

void* sfsTableAddRecord(SFSTable **ptable);   //fi
SFSVarchar* sfsTableAddVarchar(SFSTable **ptable, uint32_t varcharLen, const char* src);  //fi

SFSDatabase* sfsDatabaseCreate();  //fi
void sfsDatabaseRelease(SFSDatabase* db);   //fi
int sfsDatabaseSave(char *fileName, SFSDatabase* db);
SFSDatabase* sfsDatabaseCreateLoad(char *fileName);
SFSTable* sfsDatabaseAddTable(SFSDatabase *db, uint32_t storSize, const SFSVarchar *recordMeta);  //fi


// return the lastest err
char *sfsErrMsg();  //fi


//tool functions declaration
int strlength(const char* src);   // return the length of src (with \0 )
void* ptrOffset(void* ptr, int offset);  // to offset the ptr
int expandTable(SFSTable **ptable, int expand_size) ;  // to expand a table  , fail return -1
void printMsgOfTable(SFSTable* table_1);
int countOffset(void* ptr1, void* ptr2);  // count the offset of two ptrs
void printMsgOfDatabase(SFSDatabase* db);

int put2buf(void * content, int size, void * buf , int freeSize) ; // put some content to buffer , fail return -1
int dbHead2buf(SFSDatabase* db , char * buf , int freeSize) ;
int table2buf(SFSTable* table, char * buf)  ;  // return the pointer to buffer
void Lock_addr_db_table(SFSDatabase * db) ;    // to change value "database" of table

SFSTable* buf2table(char * buf , SFSDatabase* db) ;     // change the info in buffer to table type and return the ptr of table

#endif


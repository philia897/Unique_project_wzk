#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "sfs.h"

extern recordSize_A;  // structure A's size also the record's size;
extern errmsg;


int sfsVarcharCons(SFSVarchar* varchar, const char* src)  // success return 0 ; fail return -1
{
    if( varchar->len < strlength(src))
        return -1;
    else
    {
        varchar->len = strlength(src);
        strcpy(varchar->buf, src);
    }
    return 0;
}

SFSVarchar* sfsVarcharCreate(uint32_t varcharSize, const char* src)
{
    SFSVarchar* pvarchar = malloc(sizeof(SFSVarchar)+varcharSize) ;
    memset(pvarchar,0,sizeof(SFSVarchar)+varcharSize);
    if(pvarchar)
    {
        pvarchar->len = varcharSize;
        strcpy(pvarchar->buf, src);
        return pvarchar;
    }
    else
        return NULL;
}

int sfsVarcharRelease(SFSVarchar *varchar)
{
    free(varchar);
    return 0;
}

int strlength(const char* src)   // return the length of src (with \0 )
{
    if(src!=NULL)
        return (strlen(src)+1);
    else
        return 0;
}

SFSTable* sfsTableCreate(uint32_t initStorSize, const SFSVarchar *recordMeta, SFSDatabase *db)
{
    SFSTable* table = (SFSTable*)malloc(initStorSize+sizeof(SFSTable));
    memset(table,0,initStorSize+sizeof(SFSTable));  // create the basic room of table
    if(table==NULL) return table;    // no room ,return NULL
    // the table initialize:
    table->database = db;
    table->freeSpace = initStorSize;
    table->lastVarchar = (SFSVarchar*)ptrOffset(table, (initStorSize + sizeof(SFSTable) - 1));   // the tail of structure, for the recordMeta is pointer , differ from file type
    *((char*)(table->lastVarchar)) = '\0';  // the tail make as \0
    table->recordMeta = recordMeta;
    table->recordNum = 0;
    table->recordSize = recordSize_A;
    table->size = initStorSize + sizeof(SFSTable) ;
    table->storSize = 0;
    table->varcharNum = 0;
    //change values in db

    if(db){
        if(db->tableNum>=16){
            printf("the db is full\n");
            table->database = NULL;
        }
        else{
            db->table[db->tableNum] = table;
            db->tableNum += 1;
            db->size += table->size;
        }
    }
    //end
    // put the record meta to the tail of table
    table->recordMeta = sfsTableAddVarchar(&table , recordMeta->len, recordMeta->buf);

    return table;   //
}

int sfsTableRelease(SFSTable *table)    // if the table is not existing, return -1, or return 0;
{
    if(table){
        SFSDatabase * db = table->database;
        if(db){
            int i = 0;
            for( ; i < db->tableNum; i++)  // resort the table array in db
            {
                if(db->table[i] == table)
                    break;
            }
            for( ; i < db->tableNum; i++)
            {
                db->table[i-1] = db->table[i];
            }
            db->tableNum -= 1;
            db->size -= table->size;
        }
        free(table);
        return 0;
    }
    else
        return -1;
}


void* sfsTableAddRecord(SFSTable **ptable)   // add a record to the table
{
    while((*ptable)->freeSpace < (*ptable)->recordSize)
    {
         if(expandTable(ptable , 5*recordSize_A))// to expand the room
            return NULL;
    }
    SFSTable* table = *ptable;
    table->freeSpace -= table->recordSize;         // free space decrease record size
    table->storSize += table->recordSize;           // storage size increase record size
    void* recordptr = ptrOffset(table,(sizeof(SFSTable)+(table->recordNum)*(table->recordSize)));  // to get the record pointer
    table->recordNum++;    // record number add 1;

    return recordptr;
}

SFSVarchar* sfsTableAddVarchar(SFSTable **ptable, uint32_t varcharLen, const char* src)
{
    while((*ptable)->freeSpace < (varcharLen+4))
    {
         if(expandTable(ptable , 5*recordSize_A))// to expand the room
            return NULL;
    }
    SFSTable* table = *ptable;
    table->freeSpace -= (varcharLen+4);         // free space decrease varcharlen
    table->storSize += (varcharLen+4);           // storage size increase varcharlen
    SFSVarchar* varchar = (SFSVarchar*)ptrOffset(table->lastVarchar, (0-varcharLen-4)); // locate the address
    varchar->len = varcharLen ;
    table->lastVarchar = varchar;
    int i = 0; for(; i < varcharLen; i++) varchar->buf[i] = *(src+i);
    table->varcharNum++;

    return varchar;
}

int expandTable(SFSTable **ptable, int expand_size)   // to expand a table  , fail return -1
{
    int LastvarcharOffset = countOffset((*ptable)->lastVarchar , *ptable);
    int i = (*ptable)->size - LastvarcharOffset;    // get length of all varchars added
    SFSTable* new_table = realloc(*ptable, ((*ptable)->size+expand_size));   // to expand the room
    if(!new_table) return -1;   // fail return -1
    char *ptr1 = ((char*)new_table+new_table->size-1) ;  // size has not changed, the original tail
    char *ptr2 = ptr1 + expand_size;   // at the tail of new table
    // to refresh some of the values of the table
    new_table->freeSpace += expand_size;   // free space increase
    new_table->lastVarchar = ptrOffset(new_table, (LastvarcharOffset+expand_size));  // lastVarchar ptr offset
    new_table->size += expand_size;   // whole size of table increase
    for(;i>0;i--)  // move the content of ptr1 to ptr2
    {
        *ptr2 = *ptr1;
        ptr1--;
        ptr2--;
    }
    *ptable = new_table;
    // to refresh the value of db
    SFSDatabase * db = new_table->database;
    if(db){
        db->size += expand_size;
    }

    return 0;
}

void printMsgOfTable(SFSTable* table_1)
{
    printf("\n--------------------------\n"
           "table info:\ntablesize:%d\t recordsize:%d\nfree space:%d\tused space:%d  \nvarcharNum:%d\t  recordNum:%d \n"
           "table to LastVarchar offset:%d\n", table_1->size,table_1->recordSize, table_1->freeSpace,
           table_1->storSize,table_1->varcharNum, table_1->recordNum,  ((void*)table_1->lastVarchar - (void*)table_1));
    printf("record meta:");
    int i = 0;for(i = 0; i<table_1->recordMeta->len;i++) printf("%d " , table_1->recordMeta->buf[i]);
    printf("the last varchar: %s\n--------------------------\n" , table_1->lastVarchar->buf);

}

void printMsgOfDatabase(SFSDatabase* db)
{
    printf("\n--------------------------\ndatabase info:\n"
           "magic:%d   crc: %x\n"
           "version:%d  size:%d  tableNum:%d\n--------------------------\n",
           db->magic, db->crc, db->version, db->size, db->tableNum);
}

int countOffset(void* ptr1, void* ptr2)  // count the offset of two ptrs
{
    return (ptr1>ptr2 ? ptr1-ptr2 : ptr2-ptr1);
}

void* ptrOffset(void* ptr, int offset)
{
    return (void*)(ptr+offset);
}

char *sfsErrMsg()
{
    return errmsg;
}

int sfsTableReserve(SFSTable **table, uint32_t storSize)   // fail return -1
{
    if((*table)->freeSpace < storSize)
        return expandTable(table , 5*recordSize_A);
    else
        return 0;
}





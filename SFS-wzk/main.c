#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "sfs.h"
#pragma pack(1)

typedef struct A{
    int8_t x0_1;
    uint32_t x1_4;
    union{
        SFSVarchar *ptr;
        uint32_t offset;
    }x2_v;
    char x3_10[10];
    union{
        SFSVarchar *ptr;
        uint32_t offset;
    }x4_v;
}A;

extern uint32_t recordSize_A = sizeof(A);    // the size of one structure
extern char errmsg[100] = {0} ;
extern uint32_t version_num = 0x0000;

int main()
{
    char AMeta_c[] = {5, 0, 0, 0, 1, 4, 0, 10, 0};
    SFSVarchar *AMeta = (SFSVarchar *)AMeta_c;    // to get the record meta

   // to make a db
    SFSDatabase* db = sfsDatabaseCreate();
    SFSTable * table = sfsDatabaseAddTable(db , 10*recordSize_A , AMeta);
    A* record = sfsTableAddRecord(&table);
    record->x1_4 = 2;
    record->x2_v.ptr = sfsTableAddVarchar(&table , 6 , "hello");
    A* record2 = sfsTableAddRecord(&table);
    record2->x4_v.ptr = sfsTableAddVarchar(&table , 6 , "world");
    printf("\nthe database is made: ");
    printMsgOfDatabase(db);
    //printMsgOfTable(db->table[0]);
    // db made with 1 table and 2 records  */
    //end
    sfsDatabaseSave("./output.sfs" , db);     //save to output.sfs file
    sfsDatabaseRelease(db);         // destroy the database

    db = sfsDatabaseCreateLoad("./output.sfs");
    printf("the data has been loaded:");
    printMsgOfDatabase(db);
    printMsgOfTable(db->table[0]);
    sfsDatabaseRelease(db);
    //printf("%d", db->table[0]);

    return 0;
}




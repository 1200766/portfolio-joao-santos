import { NgModule } from '@angular/core';
import { BrowserModule } from '@angular/platform-browser';
import { HttpClientModule } from '@angular/common/http';
import { RouterModule } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { ScheduleModule, RecurrenceEditorModule } from '@syncfusion/ej2-angular-schedule';
import { AppComponent } from './app.component';
import { UtentesListaComponent } from './utentes-lista/utentes-lista.component';
import { FilterUtentesPipe } from './pipes/filter-utentes.pipe';
import { MedicosListaComponent } from './medicos-lista/medicos-lista.component';
import { routes } from './app.routes';
import { AdministradoresListaComponent } from './administradores-lista/administradores-lista.component';
import { CalendarioComponent } from './calendario/calendario.component';
import { CUSTOM_ELEMENTS_SCHEMA } from '@angular/core';
import { UtentesListaMedComponent } from './utentes-lista-med/utentes-lista-med.component';
import { LoginComponent } from './login/login.component';


import { HTTP_INTERCEPTORS } from '@angular/common/http';




@NgModule({
  declarations: [
    CalendarioComponent
  ],  // vazio, pois os componentes são standalone
  imports: [
    BrowserModule,
    HttpClientModule,
    FormsModule,
    RouterModule.forRoot(routes),
    ScheduleModule,
    RecurrenceEditorModule,

    // Importar os standalone components e pipes aqui
    AppComponent,
    UtentesListaComponent,
    FilterUtentesPipe,
    MedicosListaComponent,
    AdministradoresListaComponent,
    UtentesListaMedComponent,
    LoginComponent
  ],
  providers: [
  ],
  bootstrap: [AppComponent],
  schemas: [CUSTOM_ELEMENTS_SCHEMA]
})
export class AppModule { }

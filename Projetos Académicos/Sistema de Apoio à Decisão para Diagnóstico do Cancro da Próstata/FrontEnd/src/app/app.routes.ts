import { Routes } from '@angular/router';
import { UtentesListaComponent } from './utentes-lista/utentes-lista.component';
import { MedicosListaComponent } from './medicos-lista/medicos-lista.component';
import { AdministradoresListaComponent } from './administradores-lista/administradores-lista.component';
import { CalendarioComponent } from './calendario/calendario.component';
import { UtentesListaMedComponent } from './utentes-lista-med/utentes-lista-med.component';
import { LoginComponent } from './login/login.component';
import { AuthGuard } from './auth.guard'; // Importar o guard

export const routes: Routes = [
  { path: '', redirectTo: 'login', pathMatch: 'full' },
  { path: 'login', component: LoginComponent },

  { 
    path: 'utentes-lista', 
    component: UtentesListaComponent, 
    canActivate: [AuthGuard], 
    data: { roles: ['admin'] }
  },
  { 
    path: 'medicos-lista', 
    component: MedicosListaComponent, 
    canActivate: [AuthGuard], 
    data: { roles: ['admin'] }
  },
  { 
    path: 'administradores-lista', 
    component: AdministradoresListaComponent, 
    canActivate: [AuthGuard], 
    data: { roles: ['admin'] }
  },
  { 
    path: 'calendario', 
    component: CalendarioComponent, 
    canActivate: [AuthGuard], 
    data: { roles: ['medico'] }
  },
  { 
    path: 'utentes', 
    component: UtentesListaMedComponent, 
    canActivate: [AuthGuard], 
    data: { roles: ['medico'] }
  },
];
